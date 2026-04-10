# IAM Module - Users, Roles, and Policies

This module creates IAM users and roles with minimum permissions following the **least privilege** principle for a secure e-commerce project.

## Overview

### Components

#### 1. **EC2 Instance Role** (`ec2_instance_role`)
This role is attached to EC2 instances with minimum permissions needed for the application to function:
- **Secrets Manager**: Read access to RDS credentials
- **CloudWatch Logs**: Write application logs
- **KMS**: Decrypt encrypted secrets
- **S3 Images**: Read/write access to images bucket (optional)

**Permissions**:
- `secretsmanager:GetSecretValue` - Only for secrets under `{namespace}/rds/*`
- `logs:CreateLogGroup,CreateLogStream,PutLogEvents` - Only for specific log groups
- `kms:Decrypt,DescribeKey` - Restricted to Secrets Manager service
- `s3:GetObject,PutObject,ListBucket` - Only for images bucket (optional)

#### 2. **Terraform/DevOps User** (`terraform_user_name`)
IAM user for infrastructure management with Terraform. Has limited permissions for:
- VPC, subnets, gateways management
- Security groups management
- EC2 instances (full CRUD)
- RDS databases (full CRUD)
- IAM (limited to `{namespace}-*` resources only)
- Secrets Manager (limited to `{namespace}/*` secrets only)
- S3 buckets: state management, images, and frontend buckets
- S3 bucket policies, versioning, and encryption configuration
- DynamoDB for Terraform state locking
- CloudWatch Logs

**Use cases**: Infrastructure automation, CI/CD pipelines, infrastructure administrators

#### 3. **SSH/SSM User** (`ssh_user_name`)
IAM user for secure remote access to EC2 instances:
- **AWS Systems Manager Session Manager**: Secure access (no SSH keys)
- **CloudWatch Logs**: Session audit logs
- **S3**: Session log storage

**Use cases**: Secure remote access to instances, debugging, operations

#### 4. **Frontend CI/CD User** (`frontend_user_name`) - Optional
IAM user dedicated to frontend deployment automation:
- **S3**: Upload/delete objects in frontend bucket only
- **CloudFront**: Create cache invalidations (for CDN cache busting)
- Limited to read-only CloudFront access for distribution discovery

**Use cases**: Automated frontend deployments via GitHub Actions, GitLab CI, etc.

#### 5. **Read-Only Group** (`read_only`)
IAM group for users that need read-only access to all resources.

---

## Variables

```hcl
variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "dev, stage, or prod"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "terraform_user_name" {
  description = "Username for Terraform/DevOps user"
  type        = string
  default     = "terraform-admin"
}

variable "enable_ssh_user" {
  description = "Enable creation of SSH/SSM user"
  type        = bool
  default     = true
}

variable "ssh_user_name" {
  description = "Username for SSH/SSM access"
  type        = string
  default     = "ec2-ssh-user"
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for images (optional, for EC2 instance role)"
  type        = string
  default     = ""
}

variable "s3_frontend_bucket_arn" {
  description = "S3 bucket ARN for frontend (optional, for CI/CD)"
  type        = string
  default     = ""
}

variable "enable_frontend_user" {
  description = "Enable creation of frontend CI/CD deployment user"
  type        = bool
  default     = false
}

variable "frontend_user_name" {
  description = "Username for frontend CI/CD deployment"
  type        = string
  default     = "frontend-deployer"
}
```

## Outputs

The module exports the following values:

```hcl
output "ec2_instance_profile_name"      # Attach to EC2 instances
output "ec2_instance_profile_arn"       # Instance profile ARN
output "terraform_user_name"            # Terraform user name
output "terraform_user_arn"             # Terraform user ARN
output "ssh_user_name"                  # SSH/SSM user name
output "ssh_user_arn"                   # SSH/SSM user ARN
output "frontend_deployer_user_name"    # Frontend CI/CD user (if enabled)
output "frontend_deployer_user_arn"     # Frontend CI/CD user ARN (if enabled)
output "read_only_group_name"           # Read-only group name
output "read_only_group_arn"            # Read-only group ARN
```

---

## Usage

### Integrating with EC2 Module

```hcl
module "iam" {
  source = "../../modules/iam"

  region       = var.region
  environment  = var.environment
  project_name = var.project_name
  
  # Optional: Pass S3 bucket ARNs for EC2 access
  s3_bucket_arn = module.s3_images.bucket_arn

  tags = {
    CostCenter = "engineering"
  }
}

module "ec2" {
  source = "../../modules/ec2"

  # ... other configurations ...
  
  iam_instance_profile = module.iam.ec2_instance_profile_name
}
```

### In Environment Configuration (dev/stage/prod)

```hcl
module "iam" {
  source = "../../modules/iam"

  region       = var.region
  environment  = "dev"
  project_name = "ecommerce"

  terraform_user_name  = "terraform-ecommerce-dev"
  enable_ssh_user      = true
  ssh_user_name        = "ec2-ssh-dev"
  enable_frontend_user = true
  frontend_user_name   = "frontend-deployer-dev"

  tags = {
    CostCenter = "engineering"
  }
}

module "s3_images" {
  source = "../../modules/s3"
  
  bucket_name          = "ecommerce-dev-images"
  environment          = "dev"
  read_access_role_arns = [module.iam.ec2_instance_role_arn]
  write_access_role_arns = [module.iam.ec2_instance_role_arn]
}

module "s3_frontend" {
  source = "../../modules/s3-frontend"
  
  bucket_name = "ecommerce-dev-frontend"
  environment = "dev"
}
```

---

## Security

### Principles Applied

1. **Least Privilege**: Only explicitly necessary permissions
2. **User Segregation**: Different users for different roles
3. **Namespacing**: Permissions limited to `{project}-{env}-*` resource prefix
4. **Resource Restrictions**: Specific ARNs instead of wildcards where possible
5. **Auditing**: CloudWatch Logs and S3 for access trail

### S3 Permissions Breakdown

#### Terraform User S3 Permissions:
- **State Bucket**: ListBucket, GetObject, PutObject, DeleteObject
- **Images Bucket**: Full CRUD on bucket and objects (with policy management)
- **Frontend Bucket**: Full CRUD on bucket and objects (with website config management)

#### EC2 Instance S3 Permissions (when bucket ARN provided):
- **Images Bucket**: GetObject, ListBucket, PutObject, DeleteObject
- Restricted to: `ecommerce-{env}-images*` bucket naming pattern

#### Frontend CI/CD User S3 Permissions:
- **Frontend Bucket**: ListBucket, GetObject, PutObject
- CloudFront invalidation for cache busting
- Restricted to: `ecommerce-{env}-frontend*` bucket naming pattern

### Best Practices

- Use access keys for Terraform user (create manually with `aws iam create-access-key`)
- Rotate access keys regularly (at least quarterly)
- Enable MFA for users with privileged access
- Use Systems Manager Session Manager instead of direct SSH
- Monitor IAM activity with CloudTrail
- Use S3 versioning for both application and frontend buckets
- Enable S3 bucket encryption (AES256 or KMS)
- Restrict public access to S3 buckets (use CloudFront for frontend delivery)

---

## Next Steps

### 1. Deploy Infrastructure

```bash
cd envs/dev
terraform plan
terraform apply
```

### 2. Create Access Keys for Terraform User

```bash
# Create access key
aws iam create-access-key --user-name terraform-ecommerce-dev

# Store in environment, CI/CD secrets, or AWS credentials file
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="wJal..."
```

### 3. Create Access Keys for Frontend User (if enabled)

```bash
aws iam create-access-key --user-name frontend-deployer-dev

# Store in GitHub Actions secrets, GitLab CI variables, or similar
GITHUB_SECRET: AWS_ACCESS_KEY_ID
GITHUB_SECRET: AWS_SECRET_ACCESS_KEY
```

### 4. Create RDS Secret in Secrets Manager

```bash
# Generate secure password
PASSWORD=$(openssl rand -base64 32)

# Create secret
aws secretsmanager create-secret \
  --name ecommerce-dev/rds/master-password \
  --secret-string "$PASSWORD"
```

### 5. Store Images Bucket ARN in IAM Variables

```bash
# Get bucket ARN from S3 module output
aws s3api head-bucket --bucket ecommerce-dev-images

# Update variables.tf or terraform.tfvars with s3_bucket_arn
s3_bucket_arn = "arn:aws:s3:::ecommerce-dev-images"
```

### 6. Configure Frontend Deployment (Optional)

```bash
# Create GitHub Actions workflow or similar with:
AWS_ACCESS_KEY_ID=<from_step_3>
AWS_SECRET_ACCESS_KEY=<from_step_3>

# Deploy command example:
aws s3 sync ./dist s3://ecommerce-dev-frontend/ --delete
aws cloudfront create-invalidation --distribution-id $CF_ID --paths "/*"
```

---

## Important Notes

1. **Access keys are NOT created automatically**
   → Create manually with `aws iam create-access-key --user-name <username>`

2. **Never hardcode secrets or access keys**
   → Use environment variables, AWS Secrets Manager, or secure CI/CD secret storage

3. **Use Session Manager instead of direct SSH**
   → More secure, fully auditable, no key management needed

4. **Enable MFA on all privileged users**
   → Especially Terraform user and ops users

5. **Rotate access keys regularly**
   → Implement quarterly or semi-annual rotation policy

6. **S3 bucket naming**
   → Images: `{project}-{env}-images`
   → Frontend: `{project}-{env}-frontend`
   → This ensures IAM policies work correctly

---

## Migration to Production

When moving to production (`envs/prod/`), consider:

```hcl
# envs/prod/main.tf

module "iam" {
  # ... same config ...
  
  # Enable frontend user for prod deployments
  enable_frontend_user = true
  frontend_user_name   = "frontend-deployer-prod"
}

module "s3_images" {
  # ... configuration ...
  
  # Enable versioning and lifecycle policies
  enable_versioning        = true
  lifecycle_expiration_days = 90  # Auto-delete old versions
}

module "s3_frontend" {
  # ... configuration ...
  
  # Enable CloudFront for CDN delivery
  enable_cloudfront = true
}
```

---

## Related Modules

- `modules/ec2` - EC2 instance with IAM instance profile
- `modules/s3` - S3 bucket for application data storage
- `modules/s3-frontend` - S3 bucket for frontend static hosting
- `modules/vpc` - VPC networking
- `modules/security_groups` - Security group definitions
- `modules/rds` - RDS database
