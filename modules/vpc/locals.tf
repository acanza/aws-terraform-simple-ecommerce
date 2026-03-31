locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      CreatedBy   = "Terraform"
    }
  )

  # Public subnets: /24 = 256 IPs per subnet
  # Private subnets: /24 = 256 IPs per subnet
  # VPC: /16 = 65536 IPs total
  public_subnet_1_cidr  = "10.0.1.0/24"
  public_subnet_2_cidr  = "10.0.2.0/24"
  private_subnet_1_cidr = "10.0.11.0/24"
  private_subnet_2_cidr = "10.0.12.0/24"
}
