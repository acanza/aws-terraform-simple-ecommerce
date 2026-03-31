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
