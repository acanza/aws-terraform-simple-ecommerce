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
  trusted_ssh_cidr  = var.trusted_ssh_cidr
  enable_http       = var.enable_http
  enable_https      = var.enable_https
  enable_medusa_api = true
  db_port           = var.db_port

  tags = {
    CostCenter = "engineering"
  }
}

# IAM Roles and Users - Users and roles with minimum permissions
module "iam" {
  source = "../../modules/iam"

  region              = var.region
  environment         = "dev"
  project_name        = "ecommerce"
  terraform_user_name = "terraform-ecommerce-dev"
  enable_ssh_user     = true
  ssh_user_name       = "ec2-ssh-dev"

  tags = {
    CostCenter = "engineering"
  }
}

# EC2 Instance - Medusa Commerce backend server
module "ec2" {
  source = "../../modules/ec2"

  region        = var.region
  environment   = "dev"
  project_name  = "ecommerce"
  instance_name = "medusa-server"
  instance_type = "t4g.small" # 2 GB RAM required for Medusa npm install

  # Deploy to public subnet 1 for internet accessibility
  subnet_id         = module.vpc.public_subnet_1_id
  security_group_id = module.security_groups.ec2_security_group_id

  # IAM instance profile for secure credential management
  iam_instance_profile = module.iam.ec2_instance_profile_name

  # SSH key pair for EC2 access
  key_name = var.ec2_key_name

  # Medusa initialization script
  user_data = local.medusa_user_data

  # Cost optimization defaults
  root_volume_size        = 30 # AL2023 AMI requires minimum 30 GB
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
  database_name     = var.medusa_database_name

  # Allow EC2 instance to connect to RDS
  allowed_security_group_ids = [module.security_groups.ec2_security_group_id]

  # Use the RDS security group from the security_groups module
  # This ensures EC2 egress rules reference the same SG that RDS uses
  rds_security_group_id = module.security_groups.rds_security_group_id

  # Development settings
  multi_az                           = false
  backup_retention_period            = 7
  skip_final_snapshot                = true  # Dev environment: faster cleanup, no snapshot needed
  enable_deletion_protection         = false # Easier cleanup in dev
  enable_storage_encryption          = true
  enable_iam_database_authentication = false # Simplified auth for dev
  enable_enhanced_monitoring         = true  # ✅ SECURITY FIX: Enable RDS CloudWatch logs
  enable_performance_insights        = false

  tags = {
    CostCenter = "engineering"
  }

  depends_on = [
    module.vpc,
    module.security_groups
  ]
}

# App Runner – Medusa Starter Storefront (Next.js SSR)
#
# Deployment order (chicken-and-egg with ECR):
#   Step 1: enable_app_runner = false → terraform apply  (creates ECR + IAM only)
#   Step 2: build & push Docker image to the ECR URL shown in storefront_ecr_repository_url output
#   Step 3: enable_app_runner = true  → terraform apply  (creates App Runner service)
module "app_runner" {
  source = "../../modules/app-runner"

  project_name = "ecommerce"
  environment  = "dev"
  region       = var.region

  # create_service gates only the App Runner service; ECR + IAM are always created
  create_service = var.enable_app_runner

  # Medusa backend API URL injected as NEXT_PUBLIC_MEDUSA_BACKEND_URL
  # Port 9000 is required — Medusa listens on 9000, not 80
  medusa_backend_url = "http://${module.ec2.public_ip}:9000"

  # Medusa Starter Storefront listens on port 8000 by default
  port = 8000

  # Cost optimisation for dev: minimum viable compute (0.5 vCPU / 1 GB)
  cpu    = "512"
  memory = "1024"

  # Single instance in dev to keep costs low (~$10/month)
  min_size        = 1
  max_size        = 1
  max_concurrency = 100

  # Redeploy automatically when a new :latest image is pushed to ECR
  auto_deployments_enabled = true

  tags = {
    CostCenter = "engineering"
  }

  depends_on = [module.ec2]
}



