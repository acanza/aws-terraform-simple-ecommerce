module "vpc" {
  source = "../../modules/vpc"

  region       = var.region
  environment  = "dev"
  vpc_cidr     = var.vpc_cidr
  project_name = "ecommerce"

  tags = {
    CostCenter = "engineering"
  }
}

module "security_groups" {
  source = "../../modules/security_groups"

  region           = var.region
  environment      = "dev"
  project_name     = "ecommerce"
  vpc_id           = module.vpc.vpc_id
  trusted_ssh_cidr = var.trusted_ssh_cidr
  enable_http      = var.enable_http
  enable_https     = var.enable_https
  db_port          = var.db_port

  tags = {
    CostCenter = "engineering"
  }
}

# IAM Roles and Users - Users and roles with minimum permissions
module "iam" {
  source = "../../modules/iam"

  region            = var.region
  environment       = "dev"
  project_name      = "ecommerce"
  terraform_user_name = "terraform-ecommerce-dev"
  enable_ssh_user   = true
  ssh_user_name     = "ec2-ssh-dev"

  # S3 bucket ARN for EC2 instance role (will be set after bucket creation)
  s3_bucket_arn = ""

  tags = {
    CostCenter = "engineering"
  }
}

# EC2 Instance - Cost-optimized baseline
module "ec2" {
  source = "../../modules/ec2"

  region        = var.region
  environment   = "dev"
  project_name  = "ecommerce"
  instance_name = "web-server-01"
  instance_type = "t4g.micro" # Free tier eligible, ARM-based

  # Deploy to public subnet 1 for internet accessibility
  subnet_id         = module.vpc.public_subnet_1_id
  security_group_id = module.security_groups.ec2_security_group_id

  # IAM instance profile for secure credential management
  iam_instance_profile = module.iam.ec2_instance_profile_name

  # Cost optimization defaults
  root_volume_size        = 8 # Minimal
  root_volume_type        = "gp3"
  enable_ebs_optimization = false
  monitoring_enabled      = false
  associate_public_ip     = true

  tags = {
    CostCenter = "engineering"
  }
}

# RDS PostgreSQL - Private database in private subnets
module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "../../modules/rds"

  project_name       = "ecommerce"
  environment        = "dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # PostgreSQL 14 configuration
  engine_version    = "14"
  instance_class    = "db.t3.micro" # Free tier eligible
  allocated_storage = 20            # GB
  storage_type      = "gp2"

  # Database credentials (use Secrets Manager in production)
  database_username = "postgres"
  database_password = var.rds_master_password
  database_name     = "ecommerce"

  # Allow EC2 instance to connect to RDS
  allowed_security_group_ids = [module.security_groups.ec2_security_group_id]

  # Development settings
  multi_az                           = false
  backup_retention_period            = 7
  skip_final_snapshot                = false
  enable_deletion_protection         = false # Easier cleanup in dev
  enable_storage_encryption          = true
  enable_iam_database_authentication = false # Simplified auth for dev
  enable_enhanced_monitoring         = false
  enable_performance_insights        = false

  tags = {
    CostCenter = "engineering"
  }

  depends_on = [
    module.vpc,
    module.security_groups,
    module.ec2
  ]
}

# S3 Bucket for storing application images
module "s3_images" {
  source = "../../modules/s3"

  bucket_name = "ecommerce-dev-images-${data.aws_caller_identity.current.account_id}"
  environment = "dev"

  enable_versioning             = true
  enable_server_side_encryption = true
  lifecycle_expiration_days     = 0 # Keep images indefinitely in dev

  # Enable CloudFront for image distribution
  enable_cloudfront          = true
  cloudfront_price_class     = "PriceClass_100"  # Cost-optimized
  cache_ttl_images           = 2592000           # 30 days

  # Allow EC2 instance role to read and write images
  read_access_role_arns  = [module.iam.ec2_instance_role_arn]
  write_access_role_arns = [module.iam.ec2_instance_role_arn]

  tags = {
    CostCenter = "engineering"
  }

  depends_on = [
    module.iam,
    module.ec2
  ]
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {
}

# S3 + CloudFront for hosting the frontend application (React, Next.js, Vue, etc.)
module "s3_frontend" {
  source = "../../modules/s3-frontend"

  bucket_name = "ecommerce-dev-frontend-${data.aws_caller_identity.current.account_id}"
  environment = "dev"

  # Enable CloudFront for global distribution
  enable_cloudfront = true
  price_class       = "PriceClass_100"  # Cost-optimized for dev (North America, Europe, Asia)

  # Cache configuration
  cache_ttl_html    = 300  # 5 minutes for HTML (quick updates)
  cache_ttl_default = 3600 # 1 hour for other assets

  # For SPA routing (React Router, Vue Router, etc.)
  index_document = "index.html"
  error_document = "index.html"  # Redirect 404 to index.html for SPA

  tags = {
    CostCenter = "engineering"
  }

  depends_on = [aws_s3_bucket.frontend]
}

# Temporary placeholder S3 bucket for module dependency
# Remove this after initial deployment
resource "aws_s3_bucket" "frontend" {
  count = 0
  tags  = {}
}

