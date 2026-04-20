#!/bin/bash
# WordPress Installation Script for Amazon Linux 2 (ARM64)
# This script installs WordPress and configures it to work with RDS PostgreSQL

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting WordPress installation...${NC}"

# Update system packages
echo -e "${YELLOW}[1/10] Updating system packages...${NC}"
yum update -y

# Install LEMP stack (Linux, Nginx, MySQL replaced with PostgreSQL, PHP)
echo -e "${YELLOW}[2/10] Installing Nginx and PHP...${NC}"
amazon-linux-extras install nginx1 -y
amazon-linux-extras install php7.4 -y

# Install PHP extensions required for WordPress
echo -e "${YELLOW}[3/10] Installing PHP extensions...${NC}"
yum install -y \
    php-fpm \
    php-gd \
    php-mbstring \
    php-opcache \
    php-xml \
    php-xmlrpc \
    php-zip \
    php-pdo \
    php-pgsql \
    postgresql

# Start PHP-FPM and Nginx services
echo -e "${YELLOW}[4/10] Starting services...${NC}"
systemctl start php-fpm
systemctl start nginx
systemctl enable php-fpm
systemctl enable nginx

# Download WordPress
echo -e "${YELLOW}[5/10] Downloading WordPress...${NC}"
cd /tmp
wget https://wordpress.org/latest.tar.gz -q
tar -xzf latest.tar.gz
rm latest.tar.gz

# Move WordPress to web root
echo -e "${YELLOW}[6/10] Setting up WordPress files...${NC}"
cp -r wordpress/* /usr/share/nginx/html/
rm -rf /usr/share/nginx/html/index.html
rm -rf wordpress

# Set proper permissions
chown -R ec2-user:ec2-user /usr/share/nginx/html/
chmod -R 755 /usr/share/nginx/html/
chmod -R 777 /usr/share/nginx/html/wp-content/

# Create WordPress configuration file
echo -e "${YELLOW}[7/10] Configuring WordPress...${NC}"
cp /usr/share/nginx/html/wp-config-sample.php /usr/share/nginx/html/wp-config.php

# Replace database configuration in wp-config.php using # as delimiter (safer for database values)
sed -i "s#database_name_here#%%DB_NAME%%#g" /usr/share/nginx/html/wp-config.php
sed -i "s#username_here#%%DB_USER%%#g" /usr/share/nginx/html/wp-config.php
sed -i "s#password_here#%%DB_PASSWORD%%#g" /usr/share/nginx/html/wp-config.php
sed -i "s#localhost#%%DB_HOST%%#g" /usr/share/nginx/html/wp-config.php

# Security keys are already in wp-config-sample.php, so we don't need to fetch them
# WordPress will auto-generate them on first access if needed

# Configure Nginx for WordPress
echo -e "${YELLOW}[8/10] Configuring Nginx...${NC}"
cat > /etc/nginx/conf.d/wordpress.conf << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
        application/json application/javascript application/xml+rss
        application/atom+xml image/svg+xml;

    # Regular files and directories
    location ~ ^/(?:index|remote|webdav|static|xmlrpc)\.php$ {
        fastcgi_pass unix:/var/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # WordPress permalinks
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Deny access to sensitive files
    location ~ /\.(ht|git) {
        deny all;
    }

    # Deny access to wp-config.php
    location = /wp-config.php {
        deny all;
    }
}
EOF

# Remove default Nginx configuration
rm -f /etc/nginx/conf.d/default.conf

# Test and reload Nginx
nginx -t
systemctl reload nginx

# Install Certbot for Let's Encrypt SSL
echo -e "${YELLOW}[9/10] Installing Certbot for SSL...${NC}"
yum install -y certbot python-certbot-nginx

# Get EC2 public IP
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create WordPress admin user via WP-CLI (optional but useful)
echo -e "${YELLOW}[10/10] Finalizing installation...${NC}"

# Wait for RDS to be ready
echo -e "${YELLOW}Waiting for RDS to be ready (this may take a moment)...${NC}"
for i in {1..30}; do
    if psql -h %%DB_HOST%% -U %%DB_USER%% -d postgres -c "SELECT 1" 2>/dev/null; then
        echo -e "${GREEN}RDS is ready!${NC}"
        break
    fi
    echo "Attempt $i/30: Retrying connection to RDS..."
    sleep 10
done

# Create WordPress database if it doesn't exist
PGPASSWORD="%%DB_PASSWORD%%" psql -h %%DB_HOST%% -U %%DB_USER%% -d postgres << EOF
CREATE DATABASE %%DB_NAME%% OWNER %%DB_USER%%;
EOF

echo -e "${GREEN}WordPress installation complete!${NC}"
echo -e "${YELLOW}WordPress URL: http://$INSTANCE_IP${NC}"
echo -e "${YELLOW}To set up HTTPS, run certbot after accessing WordPress first${NC}"
echo -e "${YELLOW}Admin User: %%ADMIN_USER%%${NC}"
