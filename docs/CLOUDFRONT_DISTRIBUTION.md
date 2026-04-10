# AWS CloudFront Distribution - Images & Frontend Verification

## ✅ Architecture Verification

Both image distribution and frontend distribution now flow through CloudFront for optimal performance and security.

---

## 📊 Distribution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Application Distribution Architecture          │
└─────────────────────────────────────────────────────────────┘

IMAGES DISTRIBUTION
==================

User Browser
    ↓ (HTTPS)
CloudFront Distribution (Images)
    ├─ Origin: S3 bucket (OAC)
    ├─ Price Class: PriceClass_100
    ├─ Cache TTL: 30 days
    └─ Endpoints: Edge locations worldwide
            ↓
S3 Bucket (ecommerce-dev-images-{account-id})
    ├─ Access: Private (OAC only)
    ├─ Encryption: SSE-S3
    ├─ Versioning: Enabled
    └─ Lifecycle: 0 days (keep forever)


FRONTEND DISTRIBUTION
====================

User Browser
    ↓ (HTTPS)
CloudFront Distribution (Frontend)
    ├─ Origin: S3 bucket (OAC)
    ├─ Price Class: PriceClass_100
    ├─ Cache TTL: HTML 5min / Assets 30 days
    ├─ SPA Routing: 404 → index.html
    └─ Endpoints: Edge locations worldwide
            ↓
S3 Bucket (ecommerce-dev-frontend-{account-id})
    ├─ Access: Private (OAC only)
    ├─ Website: Configured
    ├─ Encryption: SSE-S3
    ├─ Versioning: Enabled
    └─ Content: Static application files
```

---

## 🔍 Configuration Comparison

| Feature | Images | Frontend |
|---------|--------|----------|
| **S3 Bucket** | ✅ Yes | ✅ Yes |
| **CloudFront Distribution** | ✅ Yes | ✅ Yes |
| **Origin Access Control (OAC)** | ✅ Yes | ✅ Yes |
| **HTTPS Enforcement** | ✅ Type: HTTPS Only | ✅ Type: Redirect HTTP→HTTPS |
| **Cache TTL** | 30 days (images) | 5min (HTML) / 30 days (assets) |
| **Compression** | ✅ Yes | ✅ Yes |
| **SPA Routing** | ❌ N/A | ✅ 404→index.html |
| **Regional Domain** | ✅ Yes | ✅ Yes |
| **Distribution ID** | ✅ Provided | ✅ Provided |

---

## 📦 Access Patterns

### Image Access Flow

```bash
User Request → CloudFront (Edge Location)
    ↓ (check cache)
    ├─ HIT: Return cached image (instant)
    └─ MISS: 
        ↓
    Fetch from S3 via OAC
        ↓
    Cache at edge location (30 days)
        ↓
    Return to user (HTTPS)
```

**Example Image URL:**
```
https://d1a2b3c4d5e6f7g.cloudfront.net/images/product-image.jpg
```

### Frontend Access Flow

```bash
User Request → CloudFront (Edge Location)
    ↓ (check cache)
    ├─ HTML file (5 min cache):
    │   ├─ HIT: Return if < 5 min old
    │   └─ MISS: Fetch from S3, cache 5min
    │
    ├─ Static assets (30 day cache):
    │   ├─ HIT: Return from cache
    │   └─ MISS: Fetch from S3, cache 30 days
    │
    └─ 404 errors → Redirect to index.html
```

**Example Frontend URLs:**
```
HTML:   https://d2b3c4d5e6f7g8h.cloudfront.net/index.html
JS:     https://d2b3c4d5e6f7g8h.cloudfront.net/static/main.abc123.js
CSS:    https://d2b3c4d5e6f7g8h.cloudfront.net/static/styles.def456.css
Images: https://d2b3c4d5e6f7g8h.cloudfront.net/images/product.jpg
```

---

## 🔐 Security Layer

Both distributions are protected by:

### ✅ Origin Access Control (OAC)
- S3 buckets are **completely private**
- Only CloudFront can access via OAC
- No public bucket policies required

### ✅ Encryption in Transit
- HTTP → HTTPS automatic redirect (Frontend)
- HTTPS only policy (Images)
- TLS 1.2+ enforced

### ✅ Encryption at Rest
- SSE-S3 on all S3 objects
- Automatic encryption by default

---

## 📊 Terraform Configuration

### Images Module Variable

```hcl
variable "enable_cloudfront" {
  description = "Enable CloudFront distribution for images"
  type        = bool
  default     = true  # ← ENABLED
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"  # ← Cost-optimized
}

variable "cache_ttl_images" {
  description = "Cache TTL for images (seconds)"
  type        = number
  default     = 2592000  # ← 30 days
}
```

### Frontend Module Variable

```hcl
variable "enable_cloudfront" {
  description = "Enable CloudFront distribution"
  type        = bool
  default     = true  # ← ENABLED
}

variable "cache_ttl_html" {
  description = "Cache TTL for HTML files"
  type        = number
  default     = 300  # ← 5 minutes
}

variable "cache_ttl_default" {
  description = "Default cache TTL"
  type        = number
  default     = 3600  # ← 1 hour
}
```

---

## 🚀 Deployment Outputs

After `terraform apply`, verify both distributions:

```bash
cd envs/dev

# IMAGE DISTRIBUTION
terraform output s3_images_cloudfront_domain
terraform output s3_images_cloudfront_distribution_id
terraform output s3_images_url

# FRONTEND DISTRIBUTION
terraform output cloudfront_domain_name
terraform output cloudfront_distribution_id
terraform output frontend_url
```

---

## 🔄 Cache Invalidation

### For Images

```bash
# Invalidate entire image cache
DIST_ID=$(terraform output -raw s3_images_cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"

# Invalidate specific image
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/images/product/*"
```

### For Frontend

```bash
# Invalidate all files
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"

# Invalidate HTML only
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*.html"

# Invalidate specific paths
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/index.html" "/styles/*"
```

---

## 📈 Performance Benefits

### Before (Without CloudFront)

```
User in Tokyo           User in São Paulo       User in Sydney
    ↓                       ↓                       ↓
S3 bucket (eu-west-3)       S3 bucket               S3 bucket
    ↓                       ↓                       ↓
~300ms latency          ~400ms latency          ~500ms latency
```

### After (With CloudFront)

```
User in Tokyo           User in São Paulo       User in Sydney
    ↓                       ↓                       ↓
Tokyo Edge (5ms)        São Paulo Edge (5ms)    Sydney Edge (5ms)
    ✓ Cached              ✓ Cached               ✓ Cached
(first request origin)  (first request origin)  (first request origin)
    ↓                       ↓                       ↓
S3 bucket (eu-west-3)       S3 bucket               S3 bucket
```

**Result:**
- Average latency: **5ms** (edge locations)
- Origin requests: 1 per cache period (not per user)
- Bandwidth savings: ~90% after cache warming

---

## 💰 Cost Analysis

### Images Distribution
- **CloudFront data transfer**: ~$0.085 per GB (PriceClass_100)
- **Regional request rate**: $0.0075 per 10,000 requests
- **S3 GET requests**: $0.0004 per 1,000 requests
- **Total (est. 100GB/month)**: ~$8-12/month

### Frontend Distribution
- **CloudFront data transfer**: ~$0.085 per GB (PriceClass_100)
- **Regional request rate**: $0.0075 per 10,000 requests
- **S3 GET requests**: $0.0004 per 1,000 requests
- **Total (est. 10GB/month)**: ~$1-2/month

**Total Monthly Cost (both distributions)**: ~$10-15/month

---

## ✅ Verification Checklist

Before deploying to production, verify:

### Images Distribution
- [ ] CloudFront distribution enabled
- [ ] OAC configured and linked
- [ ] S3 bucket policy allows CloudFront
- [ ] Cache TTL set appropriately (30 days)
- [ ] Compression enabled
- [ ] HTTPS only policy enforced
- [ ] CloudFront domain name working
- [ ] Images accessible via CloudFront URL

### Frontend Distribution
- [ ] CloudFront distribution enabled
- [ ] OAC configured and linked
- [ ] S3 website configuration working
- [ ] SPA routing (404 → index.html) configured
- [ ] HTML cache TTL: 5 minutes
- [ ] Asset cache TTL: 30 days
- [ ] HTTPS enforcement active
- [ ] Frontend accessible via CloudFront domain

### Both
- [ ] Distribution IDs obtained for cache invalidation
- [ ] Monitoring/alarms configured
- [ ] Access logs enabled (optional)
- [ ] CloudWatch metrics observed
- [ ] No 403 (Access Denied) errors

---

## 🔗 Related Documentation

- [S3 Images Module](../../modules/s3/README.md)
- [S3 Frontend Module](../../modules/s3-frontend/README.md)
- [S3 Images Setup](S3_IMAGES_SETUP.md)
- [S3 Frontend Setup](S3_FRONTEND_SETUP.md)
- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
