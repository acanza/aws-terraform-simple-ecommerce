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
