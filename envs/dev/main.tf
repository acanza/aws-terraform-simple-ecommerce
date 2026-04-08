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
