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

# ============================================================
# EC2 Instance
# ============================================================

output "ec2_instance_id" {
  description = "Instance ID of the EC2 web server"
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2.private_ip
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = module.ec2.public_dns
}

output "ec2_instance_state" {
  description = "State of the EC2 instance (running, stopped, etc.)"
  value       = module.ec2.instance_state
}
