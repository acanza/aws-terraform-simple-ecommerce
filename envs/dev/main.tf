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
  medusa_api_cidr  = var.medusa_api_cidr
  db_port          = var.db_port

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

  # MEDUSA_BACKEND_URL: server-side (SSR / Next.js middleware) uses the private IP
  # so App Runner → EC2 traffic stays inside the VPC via the VPC Connector.
  # Using the public IP for server-side would exit via NAT; the source IP reaching
  # EC2 would be the NAT EIP, not the App Runner SG, so the SG reference rule fails.
  medusa_backend_url = "http://${module.ec2.private_ip}:9000"

  # NEXT_PUBLIC_MEDUSA_BACKEND_URL: this is baked into the browser JS bundle at
  # build time and executed in the user's browser — it must be the PUBLIC IP/domain,
  # because browsers cannot reach a private VPC address.
  # We override only the NEXT_PUBLIC_ variant via env_vars while keeping
  # MEDUSA_BACKEND_URL (server-side) as the private IP above.
  env_vars = {
    NEXT_PUBLIC_MEDUSA_BACKEND_URL = "http://${module.ec2.public_ip}"
  }

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

  # VPC Connector: routes App Runner → EC2 traffic internally (no public port 9000)
  # Uses private subnets so internet-bound traffic exits via the NAT gateway
  enable_vpc_connector            = true
  subnet_ids                      = module.vpc.private_subnets
  vpc_connector_security_group_id = module.security_groups.app_runner_security_group_id

  tags = {
    CostCenter = "engineering"
  }

  depends_on = [module.ec2]
}

# ============================================================
# CLOUDWATCH ALARMS — Minimum viable monitoring
# ============================================================
# SNS topic: all alarms publish here. Subscribe an email address
# via var.alarm_email to receive notifications.

resource "aws_sns_topic" "alarms" {
  name = "ecommerce-dev-alarms"

  tags = {
    Environment = "dev"
    Project     = "ecommerce"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email != null ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ────────────────────────────────────────────────────────────
# EC2 Alarms
# ────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "ecommerce-dev-ec2-cpu-high"
  alarm_description   = "EC2 CPU utilization above 80% for 10 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300 # 5 minutes
  evaluation_periods  = 2   # 2 consecutive periods = 10 min before triggering
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = module.ec2.instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = "dev"
    Project     = "ecommerce"
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  alarm_name          = "ecommerce-dev-ec2-status-check-failed"
  alarm_description   = "EC2 status check failed — instance may be unreachable or impaired"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching" # Missing data means the instance may be down

  dimensions = {
    InstanceId = module.ec2.instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = "dev"
    Project     = "ecommerce"
    ManagedBy   = "Terraform"
  }
}

# ────────────────────────────────────────────────────────────
# RDS Alarms — only when RDS is enabled
# ────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.enable_rds ? 1 : 0

  alarm_name          = "ecommerce-dev-rds-cpu-high"
  alarm_description   = "RDS CPU utilization above 80% for 10 minutes"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = "dev"
    Project     = "ecommerce"
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  count = var.enable_rds ? 1 : 0

  alarm_name          = "ecommerce-dev-rds-low-storage"
  alarm_description   = "RDS free storage below 2 GB — consider increasing allocated_storage"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648 # 2 GB in bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = "dev"
    Project     = "ecommerce"
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  count = var.enable_rds ? 1 : 0

  alarm_name          = "ecommerce-dev-rds-high-connections"
  alarm_description   = "RDS database connections above 80 — db.t3.micro max is ~88"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = "dev"
    Project     = "ecommerce"
    ManagedBy   = "Terraform"
  }
}

