output "vpc_id" {
  description = "ID of the dev VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs in dev environment"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnet IDs in dev environment"
  value       = module.vpc.private_subnets
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP in dev environment"
  value       = module.vpc.nat_gateway_ip
}

# ============================================================
# Security Groups
# ============================================================

output "ec2_security_group_id" {
  description = "ID of EC2 security group (for public instances)"
  value       = module.security_groups.ec2_security_group_id
}

output "rds_security_group_id" {
  description = "ID of RDS security group (for private database)"
  value       = module.security_groups.rds_security_group_id
}

output "security_groups" {
  description = "Map of all security group IDs"
  value       = module.security_groups.security_groups
}
