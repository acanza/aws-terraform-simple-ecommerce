# S3 Frontend Hosting - Implementation Guide

## ✅ Components Implemented

A production-ready S3 + CloudFront module has been created for hosting the frontend application:

### 1. **S3 Frontend Module** (`modules/s3-frontend/`)
- ✅ S3 bucket configured for website hosting
- ✅ CloudFront CDN for global content delivery
- ✅ HTTPS/TLS encryption
- ✅ SPA routing (automatic 404 → index.html for React, Vue, Next.js)
- ✅ Optimized caching strategies (different TTLs for HTML vs assets)
- ✅ Origin Access Control (OAC) for secure S3 access
- ✅ Versioning for rollback capability

### 2. **Dev Integration** (`envs/dev/`)
- ✅ S3 frontend bucket created
- ✅ CloudFront distribution enabled (PriceClass_100 for cost optimization)
- ✅ Unique name: `ecommerce-dev-frontend-{account-id}`
- ✅ SPA routing configured (404 → index.html)

---

## 📊 Caching Strategy

The module implements intelligent caching for optimal performance and fast updates:

```
┌─────────────────────────────────────┐
│  Frontend CloudFront Caching        │
├─────────────────────────────────────┤
│                                     │
│ HTML Files (*.html)                │
│ ├─ TTL: 5 minutes (300s)           │
│ └─ Quick updates & fixes           │
│                                     │
│ Static Assets (static/*)            │
│ ├─ JS, CSS, Images                 │
│ ├─ TTL: 30 days (2,592,000s)       │
│ └─ Fingerprinted filenames         │
│                                     │
│ Other Files                        │
│ ├─ TTL: 1 hour (3600s)             │
│ └─ Default behavior                │
│                                     │
│ SPA Routing                        │
│ ├─ 404 errors → index.html         │
│ ├─ 403 errors → index.html         │
│ └─ Allows client-side routing      │
│                                     │
└─────────────────────────────────────┘
```

---

## 🚀 Deployment Steps

### 1. Initialize Terraform

```bash
cd envs/dev
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Apply (when ready)

```bash
terraform apply
```

### 4. Build Your Frontend

```bash
# Example for React/Next.js
npm install
npm run build

# Output directory: ./build (or ./out, ./dist depending on framework)
```

### 5. Deploy to S3

#### Option A: Using AWS CLI (Recommended)

```bash
# Get bucket name from Terraform outputs
BUCKET=$(cd envs/dev && terraform output -raw s3_frontend_bucket_name)
DIST_ID=$(cd envs/dev && terraform output -raw cloudfront_distribution_id)

# Upload files to S3 (delete files not in local build)
aws s3 sync ./build s3://$BUCKET/ --delete

# Invalidate CloudFront cache for instant updates
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

#### Option B: Using Deployment Script

Create `deploy-frontend.sh`:

```bash
#!/bin/bash
set -e

BUCKET=$(cd envs/dev && terraform output -raw s3_frontend_bucket_name)
DIST_ID=$(cd envs/dev && terraform output -raw cloudfront_distribution_id)
BUILD_DIR="./build"

if [ ! -d "$BUILD_DIR" ]; then
  echo "❌ Build directory not found: $BUILD_DIR"
  exit 1
fi

echo "📤 Uploading to S3: s3://$BUCKET"
aws s3 sync $BUILD_DIR s3://$BUCKET/ --delete

echo "🔄 Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"

echo "✅ Frontend deployed successfully!"
echo "🌐 URL: https://$BUCKET.s3.amazonaws.com/index.html"
```

Run it:
```bash
chmod +x deploy-frontend.sh
./deploy-frontend.sh
```

---

## 📱 Frontend URLs

After deployment, access your frontend at:

### CloudFront Distribution (Recommended)
```
https://d1234567890abc.cloudfront.net/
```

### S3 Website Endpoint (Direct)
```
http://ecommerce-dev-frontend-123456789012.s3-website-eu-west-3.amazonaws.com/
```

Get the CloudFront URL from outputs:
```bash
cd envs/dev
terraform output frontend_url
```

---

## 🔧 Framework-Specific Integration

### React

```javascript
// App.js - Example with React Router
import { BrowserRouter, Routes, Route } from 'react-router-dom';

function App() {
  return (
    <BrowserRouter basename="/">
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/products" element={<Products />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  );
}
```

Build configuration:
```json
{
  "homepage": "https://your-cloudfront-domain.cloudfront.net",
  "scripts": {
    "build": "react-scripts build"
  }
}
```

### Next.js

```javascript
// next.config.js
module.exports = {
  basePath: '',
  assetPrefix: 'https://your-cloudfront-domain.cloudfront.net',
  trailingSlash: true,
};
```

Build & deploy:
```bash
npm run build
npm run export  # Static export
aws s3 sync out s3://ecommerce-dev-frontend-xxx/ --delete
```

### Vue.js

```javascript
// vite.config.js
export default {
  base: '/',
  build: {
    outDir: 'dist',
    assetsDir: 'static',
  },
};
```

Build:
```bash
npm run build
aws s3 sync dist s3://ecommerce-dev-frontend-xxx/ --delete
```

---

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Frontend to S3

on:
  push:
    branches: [main]
    paths:
      - 'frontend/**'  # Only deploy on frontend changes
      - '.github/workflows/deploy-frontend.yml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: cd frontend && npm install
      
      - name: Build application
        run: cd frontend && npm run build
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-3
      
      - name: Deploy to S3
        run: |
          BUCKET=$(cd envs/dev && terraform output -raw s3_frontend_bucket_name)
          aws s3 sync frontend/build s3://$BUCKET/ --delete --cache-control "max-age=3600"
      
      - name: Invalidate CloudFront cache
        run: |
          DIST_ID=$(cd envs/dev && terraform output -raw cloudfront_distribution_id)
          aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

---

## 📊 Outputs Available

After applying `terraform apply`, get these outputs:

```bash
cd envs/dev

# S3 bucket name
terraform output s3_frontend_bucket_name

# CloudFront domain
terraform output cloudfront_domain_name

# Distribution ID (for invalidation)
terraform output cloudfront_distribution_id

# Full URL to frontend
terraform output frontend_url
```

---

## 🔐 Security

### ✅ Implemented

| Feature | Status | Details |
|---------|--------|---------|
| HTTPS | ✅ | Automatic HTTP → HTTPS redirect |
| Encryption | ✅ | SSE-S3 on all objects |
| Versioning | ✅ | Rollback to previous versions |
| Origin Access | ✅ | CloudFront OAC restricts S3 access |
| Public Access | ✅ | Intentionally public (website requirement) |

### ⚠️ Best Practices

1. **Never store secrets in frontend code**
   - Use environment variables for API endpoints
   - Implement authentication via backend

2. **Use backend APIs for sensitive operations**
   - Don't expose AWS credentials
   - Validate requests server-side

3. **Implement Content Security Policy (CSP)**
   ```html
   <meta http-equiv="Content-Security-Policy" 
         content="default-src 'self'; script-src 'self'">
   ```

4. **Monitor CloudFront errors**
   - Set up CloudWatch alarms
   - Track 4xx/5xx error rates

---

## 🎯 Production Configuration

### Enable Custom Domain

```hcl
# In envs/prod/main.tf or when ready for production

module "s3_frontend" {
  source = "../../modules/s3-frontend"

  bucket_name = "ecommerce-prod-frontend-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  enable_cloudfront      = true
  price_class            = "PriceClass_All"  # All edge locations
  enable_ssl_certificate = true
  ssl_certificate_arn    = aws_acm_certificate.frontend.arn
  domain_name            = "app.yourdomain.com"

  # Longer cache for production
  cache_ttl_html    = 600   # 10 minutes
  cache_ttl_default = 86400 # 1 day

  tags = {
    Environment = "production"
    CostCenter  = "marketing"
  }
}
```

---

## 🛠️ Troubleshooting

### CloudFront returning 403 (Access Denied)

```bash
# Verify bucket policy
aws s3api get-bucket-policy --bucket ecommerce-dev-frontend-xxx

# Check CloudFront OAC
aws cloudfront get-origin-access-control --id <OAC-ID>
```

### SPA routing not working (404 errors)

Verify the module is configured with:
```hcl
index_document = "index.html"
error_document = "index.html"
```

### Files not updating after upload

Invalidate CloudFront cache:
```bash
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*"
```

### Images not showing (403 error)

If images are stored in the images bucket:
```html
<!-- Use CloudFront domain for images -->
<img src="https://cloudfront-domain/images/product.jpg" />
```

---

## 📈 Monitoring & Analytics

### CloudFront Metrics

```bash
# View distribution metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --dimensions Name=DistributionId,Value=DISTRIBUTION_ID \
  --start-time 2024-04-01T00:00:00Z \
  --end-time 2024-04-10T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### S3 Metrics

```bash
# Enable request metrics for the bucket
aws s3api put-bucket-metrics-configuration \
  --bucket ecommerce-dev-frontend-xxx \
  --id EntireBucket \
  --metrics-configuration '{"Id":"EntireBucket","Filter":{"Prefix":""}}'
```

---

## ⚡ Performance Optimization

### 1. Use Fingerprinted Asset Names

Build tools automatically generate hashed filenames:
```
main.abc123.js  (changes hash on update)
styles.def456.css
```

This allows unlimited caching of these files.

### 2. Enable Compression

CloudFront automatically compresses text:
- JavaScript
- CSS
- HTML
- JSON

### 3. Minify Assets

```bash
# React
npm run build

# Next.js
npm run build

# Vue
npm run build
```

### 4. Use WebP Images

```html
<picture>
  <source srcset="image.webp" type="image/webp">
  <img src="image.jpg" alt="Description">
</picture>
```

---

## 🔗 References

- [S3 Frontend Module](../../modules/s3-frontend/README.md)
- [S3 Images Module](../../modules/s3/README.md)
- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
