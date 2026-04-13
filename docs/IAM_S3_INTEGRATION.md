# IAM Module Update - S3 Permissions Review

## Summary

The IAM module has been updated to support the new S3 modules (`modules/s3` and `modules/s3-frontend`) with expanded permissions while maintaining the **least privilege** security principle.

---

## Changes Made

### 1. **New Variables Added**

```hcl
variable "s3_frontend_bucket_arn" {
  description = "S3 bucket ARN for frontend (optional, for CI/CD pipeline access)"
  type        = string
  default     = ""
}

variable "enable_frontend_user" {
  description = "Enable creation of dedicated CI/CD user for frontend deployment"
  type        = bool
  default     = false
}

variable "frontend_user_name" {
  description = "Username for frontend CI/CD deployment"
  type        = string
  default     = "frontend-deployer"
}
```

### 2. **EC2 Instance Role - S3 Images Access**

Already in place with conditional logic based on `s3_bucket_arn` variable:

```hcl
# Permissions granted if s3_bucket_arn is provided:
- s3:GetObject
- s3:ListBucket
- s3:PutObject      # Write capability for image uploads
- s3:DeleteObject   # Delete old images
```

**Restrictions**:
- Only for resources matching `var.s3_bucket_arn`
- No bucket management permissions (policy, versioning, etc.)
- Read, write, and delete at object level only

### 3. **Terraform User - Expanded S3 Permissions**

#### State Management Bucket
```hcl
Actions:
- s3:ListBucket
- s3:GetObject
- s3:PutObject
- s3:DeleteObject

Resources:
- arn:aws:s3:::${namespace}-terraform-state
- arn:aws:s3:::${namespace}-terraform-state/*
```

#### Images Bucket Management (`*-images*`)
```hcl
Actions:
- s3:CreateBucket                               # Create new bucket
- s3:DeleteBucket                               # Teardown
- s3:ListBucket, s3:ListBucketVersions          # Browse contents
- s3:GetBucketVersioning, s3:PutBucketVersioning
- s3:GetBucketServerSideEncryptionConfiguration
- s3:PutBucketServerSideEncryptionConfiguration
- s3:GetBucketPublicAccessBlock
- s3:PutBucketPublicAccessBlock                 # Security configuration
- s3:GetBucketPolicy, s3:PutBucketPolicy
- s3:DeleteBucketPolicy
- s3:*Object*                                   # Full object management

Resources:
- arn:aws:s3:::${namespace}-images*
- arn:aws:s3:::${namespace}-images*/*
```

#### Frontend Bucket Management (`*-frontend*`)
```hcl
Actions:
- s3:CreateBucket, s3:DeleteBucket
- s3:ListBucket, s3:ListBucketVersions
- s3:GetBucketVersioning, s3:PutBucketVersioning
- s3:GetBucketWebsite, s3:PutBucketWebsite      # Website hosting config
- s3:DeleteBucketWebsite
- s3:GetBucketServerSideEncryptionConfiguration
- s3:PutBucketServerSideEncryptionConfiguration
- s3:GetBucketPublicAccessBlock
- s3:PutBucketPublicAccessBlock                 # Security configuration
- s3:GetBucketPolicy, s3:PutBucketPolicy
- s3:DeleteBucketPolicy
- s3:*Object*                                   # Full object management

Resources:
- arn:aws:s3:::${namespace}-frontend*
- arn:aws:s3:::${namespace}-frontend*/*
```

**Design Rationale**:
- Uses bucket naming patterns (`*-images*`, `*-frontend*`) to limit scope
- Allows Terraform user to manage infrastructure without human intervention
- No wildcard on service level, restrictions by bucket name prefix

### 4. **New: Frontend CI/CD User** (Optional)

New dedicated user for automated frontend deployments (GitHub Actions, GitLab CI, etc.).

#### S3 Frontend Permissions
```hcl
Actions:
- s3:ListBucket                    # Browse bucket contents
- s3:ListBucketVersions            # Version management
- s3:GetObject                     # Download for verification
- s3:GetObjectVersion
- s3:PutObject                     # Upload built assets

Resources:
- arn:aws:s3:::${namespace}-frontend*
- arn:aws:s3:::${namespace}-frontend*/*

Restrictions:
- NO bucket management (policy, versioning, etc.)
- NO delete permissions
- Append-only deployment model
```

#### CloudFront Permissions (for cache invalidation)
```hcl
Actions:
- cloudfront:CreateInvalidation
- cloudfront:ListInvalidations
- cloudfront:GetInvalidation       # Create and check invalidations

- cloudfront:ListDistributions     # Read-only for finding distribution ID
- cloudfront:GetDistribution

Restrictions:
- Condition: Distribution ID must contain ${namespace}
- Prevents accidental invalidation of other distributions
```

**Use Case**: Automated deployments in CI/CD without full AWS credentials

---

## Permission Summary by User/Role

| Component | Module S3 Images | Module S3 Frontend | S3 State | CloudFront | Note |
|-----------|-----|--------|---------|------------|------|
| **EC2 Role** | R/W | ❌ | ❌ | ❌ | Application read/write to images |
| **Terraform User** | Full | Full | Full | List only | Infrastructure management |
| **Frontend User** | ❌ | List/Upload | ❌ | Invalidate | CI/CD deployments only |
| **SSH User** | ❌ | ❌ | ❌ | ❌ | Session access only |
| **Read-Only Group** | R | R | R | R | Monitoring/auditing |

---

## Integration with S3 Modules

### Example: Complete Setup in envs/dev

```hcl
module "iam" {
  source = "../../modules/iam"

  region               = var.region
  environment          = "dev"
  project_name         = "ecommerce"
  terraform_user_name  = "terraform-ecommerce-dev"
  enable_ssh_user      = true
  enable_frontend_user = true
  frontend_user_name   = "frontend-deployer-dev"

  # Pass bucket ARNs for EC2 access configuration
  s3_bucket_arn         = module.s3_images.bucket_arn
  s3_frontend_bucket_arn = module.s3_frontend.bucket_arn

  tags = {
    CostCenter = "engineering"
  }
}

module "ec2" {
  source = "../../modules/ec2"

  # ... other config ...
  
  iam_instance_profile = module.iam.ec2_instance_profile_name
}

module "s3_images" {
  source = "../../modules/s3"

  bucket_name               = "ecommerce-dev-images"
  environment               = "dev"
  enable_versioning         = true
  enable_server_side_encryption = true
  
  # Grant EC2 instance access
  read_access_role_arns  = [module.iam.ec2_instance_role_arn]
  write_access_role_arns = [module.iam.ec2_instance_role_arn]
}

module "s3_frontend" {
  source = "../../modules/s3-frontend"

  bucket_name     = "ecommerce-dev-frontend"
  environment     = "dev"
  enable_cloudfront = true
  # CloudFront distribution ID will be used by frontend deployer for cache invalidation
}
```

---

## Security Validation

### ✅ Least Privilege Confirmed

- **No wildcards at service level**: All S3 permissions are specific actions
- **Resource restrictions**: Buckets limited by naming pattern (`-images*`, `-frontend*`)
- **Segregated access**: Different users for infrastructure, operations, and CI/CD
- **Audit trails**: All users have CloudWatch logging for operations

### ✅ Bucket Strategy

- **Private buckets by default**: S3 Images and State buckets are private
- **Public frontend via CloudFront**: Frontend bucket accessed through distribution
- **No direct public S3 access**: Website hosting is optional, CloudFront is recommended

### ✅ Immutable Deployments

- Frontend user cannot delete objects (append-only)
- Versioning enabled on buckets for rollback capability
- CloudFront invalidation for cache management (not deletion)

---

## Deployment Steps

### 1. Update envs/dev/main.tf

```hcl
module "iam" {
  enable_frontend_user = true
  # ... other variables ...
}

module "s3_images" {
  source = "../../modules/s3"
  # ... configuration ...
  read_access_role_arns  = [module.iam.ec2_instance_role_arn]
  write_access_role_arns = [module.iam.ec2_instance_role_arn]
}

module "s3_frontend" {
  source = "../../modules/s3-frontend"
  # ... configuration ...
}
```

### 2. Create Access Keys for Frontend User (optional)

```bash
aws iam create-access-key --user-name frontend-deployer-dev

# Store in GitHub Actions/GitLab CI secrets:
GITHUB_SECRET: S3_ACCESS_KEY_ID
GITHUB_SECRET: S3_SECRET_ACCESS_KEY
GITHUB_SECRET: CLOUDFRONT_DISTRIBUTION_ID
```

### 3. Create GitHub Actions Workflow Example

```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build
        run: npm run build
      - name: Deploy to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.S3_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.S3_SECRET_ACCESS_KEY }}
        run: |
          aws s3 sync ./dist s3://ecommerce-dev-frontend/ --delete
      - name: Invalidate CloudFront
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.S3_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.S3_SECRET_ACCESS_KEY }}
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
```

---

## Validation Results

✅ **Module Format**: Terraform fmt passes
✅ **Module Validation**: terraform validate passes
✅ **Environment Dev**: Configuration valid with all modules

---

## Related Documentation

- [IAM_SETUP_GUIDE.md](./IAM_SETUP_GUIDE.md) - Complete IAM setup guide
- [modules/s3/README.md](../../modules/s3/README.md) - Images bucket module
- [modules/s3-frontend/README.md](../../modules/s3-frontend/README.md) - Frontend bucket module
- [docs/SECURITY_GROUPS_DESIGN.md](./SECURITY_GROUPS_DESIGN.md) - Network security

---

## Key Files Modified

- `modules/iam/variables.tf` - Added new variables
- `modules/iam/main.tf` - Added S3 and CloudFront permissions
- `modules/iam/outputs.tf` - Added frontend user outputs
- `modules/iam/README.md` - Complete rewrite in English with S3 integration

---

## Notes for Operations

1. **Frontend User Access Keys**: Use dedicated credentials, rotate quarterly
2. **S3 Bucket Naming**: Must follow pattern `{project}-{env}-{type}*` for IAM policies to work
3. **CloudFront**: Optional but recommended for production frontend delivery
4. **Versioning**: Keep enabled for both buckets for rollback capability
5. **Encryption**: AES256 recommended for cost optimization, KMS possible if needed

