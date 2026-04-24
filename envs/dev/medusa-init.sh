#!/bin/bash
# Medusa Commerce Installation Script for Amazon Linux 2 (ARM64)
# This script installs Medusa and configures it to work with RDS PostgreSQL

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Medusa Commerce installation...${NC}"

# ============================================================
# 1. Update system packages and install prerequisites
# ============================================================
echo -e "${YELLOW}[1/9] Updating system packages and installing dependencies...${NC}"
# AL2023 uses dnf; amazon-linux-extras is not available
# --allowerasing replaces curl-minimal (pre-installed in AL2023) with full curl
dnf update -y
dnf install -y --allowerasing \
    postgresql15 \
    git \
    curl \
    wget \
    python3 \
    make \
    gcc \
    gcc-c++

# ============================================================
# 2. Install Node.js 20 via NodeSource (Medusa v2 requires Node >= 20)
# ============================================================
# AL2023 ships with glibc 2.34; NodeSource Node 20 ARM64 binaries are compatible.
echo -e "${YELLOW}[2/9] Installing Node.js 20 LTS via NodeSource...${NC}"
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs
node --version
npm --version

# Install Nginx (available directly in AL2023 base repos)
echo -e "${YELLOW}[2b/9] Installing Nginx...${NC}"
dnf install -y nginx

# Create swap file to prevent OOM during npm install (t4g.micro has only 1 GB RAM)
# Medusa's npm install requires ~1.5 GB; swap ensures it completes successfully
echo -e "${YELLOW}[2c/9] Creating 2 GB swap file for npm install...${NC}"
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# create-medusa-app uses npm (--use-npm flag); yarn is not needed
# Redis is NOT required in dev: Medusa v2 uses Local Event Module (Node EventEmitter) by default

# ============================================================
# 3. Create Medusa application directory
# ============================================================
echo -e "${YELLOW}[3/9] Creating Medusa application directory...${NC}"
mkdir -p /opt/medusa
cd /opt/medusa

# ============================================================
# 4. Initialize Medusa project
# ============================================================
echo -e "${YELLOW}[4/9] Initializing Medusa project...${NC}"
# create-medusa-app v2 flags (from official docs):
#   --skip-db: skips DB creation, migrations, and seeding (we configure RDS manually below)
#   --no-browser: prevents opening a browser at the end
#   --use-npm: avoids yarn/pnpm conflicts in this environment
# 'yes n' continuously pipes "n" to answer any interactive prompts (e.g. Next.js storefront)
# NODE_OPTIONS increases V8 heap limit beyond default ~512MB to use available RAM + swap
export NODE_OPTIONS="--max-old-space-size=3072"
yes n | npx create-medusa-app@latest medusa-store --skip-db --no-browser --use-npm

cd medusa-store

# ============================================================
# 5. Configure environment variables for PostgreSQL
# ============================================================
echo -e "${YELLOW}[5/9] Configuring Medusa environment...${NC}"
cat > .env.production << EOF
# Database Configuration
DATABASE_URL="postgresql://%%DB_USER%%:%%DB_PASSWORD%%@%%DB_HOST%%:5432/%%DB_NAME%%"

# Medusa Server Configuration
NODE_ENV="production"
JWT_SECRET="$(openssl rand -base64 32)"
COOKIE_SECRET="$(openssl rand -base64 32)"

# Worker mode (shared = server + worker in a single process, valid for dev)
MEDUSA_WORKER_MODE="shared"

# CORS
STORE_CORS="*"
ADMIN_CORS="*"
AUTH_CORS="*"

# Port configuration
PORT=9000
EOF

# Also create .env for development
cp .env.production .env

# ============================================================
# 6. Build Medusa
# ============================================================
# create-medusa-app already ran npm install; just build.
# Using npm (project was created with --use-npm; yarn causes MODULE_NOT_FOUND).
echo -e "${YELLOW}[6/9] Building Medusa backend (npx medusa build)...${NC}"
# create-medusa-app@2.14.0 generates a broken 'build' script ('npm -r build').
# Calling 'npx medusa build' directly bypasses the broken package.json script.
npx medusa build

# ============================================================
# 7. Wait for RDS and create database
# ============================================================
echo -e "${YELLOW}[7/9] Setting up PostgreSQL database...${NC}"
# Wait for RDS to be ready
echo -e "${YELLOW}Waiting for RDS to be ready (this may take a moment)...${NC}"
for i in {1..30}; do
    if PGPASSWORD="%%DB_PASSWORD%%" psql -h %%DB_HOST%% -U %%DB_USER%% -d postgres -c "SELECT 1" 2>/dev/null; then
        echo -e "${GREEN}RDS is ready!${NC}"
        break
    fi
    echo "Attempt $i/30: Retrying connection to RDS..."
    sleep 10
done

# Create Medusa database only if it doesn't already exist
# (the RDS instance may already have a database from a previous run)
PGPASSWORD="%%DB_PASSWORD%%" psql -h %%DB_HOST%% -U %%DB_USER%% -d postgres -c \
  "SELECT 1 FROM pg_database WHERE datname='%%DB_NAME%%'" | grep -q 1 || \
  PGPASSWORD="%%DB_PASSWORD%%" psql -h %%DB_HOST%% -U %%DB_USER%% -d postgres -c \
  "CREATE DATABASE %%DB_NAME%% OWNER %%DB_USER%%"

# Install deps in .medusa/server and run migrations (predeploy = medusa db:migrate)
echo -e "${YELLOW}Installing production dependencies and running migrations...${NC}"
cd /opt/medusa/medusa-store/.medusa/server
npm install
# Copy env file so systemd EnvironmentFile and predeploy script can read it
cp /opt/medusa/medusa-store/.env.production .env
npm run predeploy
cd /opt/medusa/medusa-store

# ============================================================
# 8. Configure systemd service for Medusa
# ============================================================
echo -e "${YELLOW}[8/9] Configuring Medusa as a systemd service...${NC}"
cat > /etc/systemd/system/medusa.service << EOF
[Unit]
Description=Medusa Commerce Backend
After=network.target postgresql.service

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/medusa/medusa-store/.medusa/server
# Medusa v2 build outputs to .medusa/server; start from there
ExecStart=/usr/bin/npm run start
Restart=always
RestartSec=10
Environment="NODE_ENV=production"
EnvironmentFile=/opt/medusa/medusa-store/.medusa/server/.env

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
chown -R ec2-user:ec2-user /opt/medusa
chmod -R 755 /opt/medusa

# ============================================================
# 9. Configure Nginx as reverse proxy
# ============================================================
echo -e "${YELLOW}[9/9] Configuring Nginx as reverse proxy...${NC}"
cat > /etc/nginx/conf.d/medusa.conf << 'EOF'
upstream medusa_backend {
    server localhost:9000;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
        application/json application/javascript application/xml+rss
        application/atom+xml image/svg+xml;

    # Proxy settings
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $server_name;
    proxy_set_header X-Forwarded-Port $server_port;

    # WebSocket support
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Timeouts for long-running requests
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Proxy to Medusa backend
    location / {
        proxy_pass http://medusa_backend;
    }

    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://medusa_backend;
    }
}
EOF

# Remove default Nginx configuration
rm -f /etc/nginx/conf.d/default.conf

# Test Nginx configuration
nginx -t

# Enable and start services
systemctl daemon-reload
systemctl enable nginx
systemctl enable medusa.service

# Start services (Medusa will start after Nginx to ensure proper port binding)
systemctl start nginx

# Add a small delay before starting Medusa to ensure database migrations complete
echo -e "${YELLOW}Waiting 10 seconds before starting Medusa service...${NC}"
sleep 10
systemctl start medusa.service

# Install Certbot for Let's Encrypt SSL (optional)
echo -e "${YELLOW}Installing Certbot for SSL support...${NC}"
dnf install -y certbot python3-certbot-nginx

# Get EC2 public IP
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo -e "${GREEN}✓ Medusa installation complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Medusa API URL: http://$INSTANCE_IP${NC}"
echo -e "${YELLOW}Medusa Admin: http://$INSTANCE_IP/app${NC}"
echo -e "${YELLOW}Health Check: http://$INSTANCE_IP/health${NC}"
echo -e "${YELLOW}To set up HTTPS, run: certbot --nginx -d your-domain.com${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"

# Display service status
systemctl status medusa.service --no-pager
echo -e "${YELLOW}View logs with: journalctl -u medusa.service -f${NC}"
