# S3 Frontend Module - Static Website Hosting

Production-ready module for hosting static frontend applications (React, Next.js, Vue, etc.) on S3 with global distribution via CloudFront.

## Features

✅ **Static Website Hosting** - S3 bucket configured for website hosting  
✅ **CloudFront CDN** - Global content delivery with edge caching  
✅ **HTTPS/TLS** - Secure connections with automatic HTTPS redirect  
✅ **SPA Routing** - Automatic 404 → index.html redirection for Single Page Apps  
✅ **Optimized Caching** - Different TTLs for HTML, static assets, and dynamic content  
✅ **Origin Access Control** - Secure S3 access from CloudFront only  
✅ **Versioning** - Rollback capability for deployments  
✅ **Encryption** - Server-side encryption enabled  

## Usage

### Basic Example

```hcl
module "s3_frontend" {
  source = "./modules/s3-frontend"

  bucket_name = "ecommerce-dev-frontend"
  environment = "dev"
  
  enable_cloudfront = true
  price_class       = "PriceClass_100"  # Cheapest: North America, Europe, Asia
}
```

### With Custom Domain (Production)

```hcl
module "s3_frontend" {
  source = "./modules/s3-frontend"

  bucket_name = "ecommerce-prod-frontend"
  environment = "prod"
  
  enable_cloudfront        = true
  price_class              = "PriceClass_All"  # All regions
  enable_ssl_certificate   = true
  ssl_certificate_arn      = aws_acm_certificate.frontend.arn
  domain_name              = "app.yourdomain.com"
}
```

### Without CloudFront (Development)

```hcl
module "s3_frontend" {
  source = "./modules/s3-frontend"

  bucket_name = "ecommerce-dev-frontend"
  environment = "dev"
  
  enable_cloudfront = false  # Use S3 website endpoint directly
  
  tags = {
    CostCenter = "development"
  }
}
```

## Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `bucket_name` | Unique bucket name (3-63 chars) | `string` | Required |
| `environment` | dev, stage, prod | `string` | Required |
| `domain_name` | Custom domain for CloudFront (optional) | `string` | `""` |
| `index_document` | Index file (typically index.html) | `string` | `index.html` |
| `error_document` | Error file for 404s (SPAs use index.html) | `string` | `index.html` |
| `routing_rules` | JSON routing rules for complex redirects | `string` | `""` |
| `enable_cloudfront` | Enable CloudFront distribution | `bool` | `true` |
| `price_class` | CloudFront price class | `string` | `PriceClass_100` |
| `cache_ttl_default` | Default cache TTL (seconds) | `number` | `3600` |
| `cache_ttl_html` | HTML files cache TTL (seconds) | `number` | `300` |
| `enable_ssl_certificate` | Enable HTTPS with ACM certificate | `bool` | `false` |
| `ssl_certificate_arn` | ACM certificate ARN | `string` | `""` |
| `tags` | Additional tags | `map(string)` | `{}` |

## Outputs

| Output | Description |
|--------|------------|
| `bucket_name` | S3 bucket name |
| `bucket_arn` | S3 bucket ARN |
| `cloudfront_domain_name` | CloudFront distribution domain |
| `cloudfront_distribution_id` | CloudFront ID (for cache invalidation) |
| `frontend_url` | Full URL to access the application |

## Caching Strategy

```
├── HTML files (*.html)           → 5 minutes (300s)
│   └─ Allows quick fixes & updates
│
├── Static assets (static/*)      → 30 days (2592000s)
│   ├─ JavaScript bundles
│   ├─ CSS stylesheets
│   └─ Images
│
└── Other files                   → 1 hour (3600s)
```

## SPA Routing Configuration

For Single Page Applications (React, Vue, Next.js), the module automatically redirects:
- **404 errors** → `index.html`
- **403 errors** → `index.html`

This allows routing to be handled by the frontend application (e.g., React Router).

## Deployment - Upload Files

### Using AWS CLI

```bash
# Build your frontend application
npm run build        # React, Vue, Next.js, etc.

# Get bucket name from outputs
BUCKET=$(terraform output frontend_bucket_name)

# Sync build folder to S3
aws s3 sync ./build s3://$BUCKET/ --delete

# Invalidate CloudFront cache
DIST_ID=$(terraform output cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

### Using Terraform for Deployment (Advanced)

```hcl
# Deploy built files using Terraform
resource "aws_s3_object" "frontend_files" {
  for_each = fileset("${path.module}/../build", "**/*")

  bucket       = module.s3_frontend.bucket_name
  key          = each.value
  source       = "${path.module}/../build/${each.value}"
  etag         = filemd5("${path.module}/../build/${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), "application/octet-stream")
}
```

## CloudFront Price Classes

| Price Class | Coverage | Cost |
|------------|----------|------|
| `PriceClass_100` | US, Europe, Asia-Pacific | Cheapest |
| `PriceClass_200` | All except expensive regions | Medium |
| `PriceClass_All` | All edge locations | Most expensive, best global performance |

## Security Considerations

### ✅ Implemented

| Feature | Status | Details |
|---------|--------|---------|
| HTTPS | ✅ | Automatic redirect from HTTP |
| Encryption | ✅ | SSE-S3 on all objects |
| Versioning | ✅ | Rollback to previous versions |
| Origin Access | ✅ | CloudFront OAC restricts direct S3 access |
| Public Access | ⚠️ | Intentionally public (website requirement) |

### ⚠️ Considerations

- Frontend is **intentionally public** (it's a website)
- Never store secrets/API keys in frontend code
- Use environment variables and backend APIs for sensitive operations
- Implement proper authentication for sensitive features

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build application
        run: npm run build
      
      - name: Deploy to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: eu-west-3
        run: |
          aws s3 sync ./build s3://${{ secrets.S3_BUCKET_NAME }}/ --delete
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DIST_ID }} \
            --paths "/*"
```

## Troubleshooting

### CloudFront returning 403 (Access Denied)

Ensure the bucket policy allows CloudFront access and OAC is properly configured.

### SPA routing not working

Verify `error_document` is set to `index.html` and CloudFront custom error responses are configured.

### Cache not invalidating

After uploading new files, invalidate CloudFront:
```bash
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*"
```

### Content not updating

Check CloudFront cache TTL. For immediate updates, invalidate cache or use versioned file names (e.g., `bundle.abc123.js`).

## Production Checklist

- [ ] Use `PriceClass_All` for best global performance
- [ ] Enable HTTPS with ACM certificate
- [ ] Configure custom domain (CNAME) in Route 53
- [ ] Set up CloudFront access logs (optional but recommended)
- [ ] Test SPA routing works correctly
- [ ] Implement cache invalidation in CI/CD
- [ ] Monitor CloudFront metrics in CloudWatch
- [ ] Set up alerts for 4xx/5xx errors

## References

- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront CDN](https://docs.aws.amazon.com/cloudfront/)
- [Origin Access Control (OAC)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
