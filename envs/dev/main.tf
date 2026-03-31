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

  region            = var.region
  environment       = "dev"
  project_name      = "ecommerce"
  vpc_id            = module.vpc.vpc_id
  trusted_ssh_cidr  = var.trusted_ssh_cidr
  enable_http       = var.enable_http
  enable_https      = var.enable_https
  db_port           = var.db_port

  tags = {
    CostCenter = "engineering"
  }
}
