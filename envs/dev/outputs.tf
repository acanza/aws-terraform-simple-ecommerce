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

# ============================================================
# RDS PostgreSQL Database
# ============================================================

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (address:port) - only accessible from within VPC"
  value       = try(module.rds[0].db_instance_endpoint, null)
  sensitive   = true
}

output "rds_address" {
  description = "RDS PostgreSQL hostname for connection strings"
  value       = try(module.rds[0].db_instance_address, null)
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = try(module.rds[0].db_instance_port, null)
}

output "rds_database_name" {
  description = "Initial database name"
  value       = try(module.rds[0].database_name, null)
}

output "rds_database_username" {
  description = "RDS master username"
  value       = try(module.rds[0].database_username, null)
  sensitive   = true
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = try(module.rds[0].db_instance_id, null)
}

output "rds_instance_arn" {
  description = "ARN of the RDS instance"
  value       = try(module.rds[0].db_instance_arn, null)
}

# ============================================================
# IAM Users, Roles & Policies
# ============================================================

output "ec2_instance_profile_name" {
  description = "IAM instance profile name attached to EC2 (for Secrets Manager and CloudWatch access)"
  value       = module.iam.ec2_instance_profile_name
}

output "terraform_user_name" {
  description = "IAM username for Terraform/DevOps infrastructure management"
  value       = module.iam.terraform_user_name
}

output "terraform_user_arn" {
  description = "IAM user ARN for Terraform/DevOps infrastructure management"
  value       = module.iam.terraform_user_arn
}

output "ssh_user_name" {
  description = "IAM username for SSH/SSM session access to EC2 instances"
  value       = module.iam.ssh_user_name
}

output "ssh_user_arn" {
  description = "IAM user ARN for SSH/SSM session access"
  value       = module.iam.ssh_user_arn
}

output "read_only_group_name" {
  description = "IAM group name for read-only access"
  value       = module.iam.read_only_group_name
}

output "read_only_group_arn" {
  description = "IAM group ARN for read-only access"
  value       = module.iam.read_only_group_arn
}

# ============================================================
# S3 Images Bucket
# ============================================================

output "s3_images_bucket_name" {
  description = "Name of the S3 bucket for storing application images"
  value       = module.s3_images.bucket_name
}

output "s3_images_bucket_arn" {
  description = "ARN of the S3 bucket for images"
  value       = module.s3_images.bucket_arn
}

output "s3_images_bucket_domain_name" {
  description = "Regional domain name of the S3 bucket (for HTTP access)"
  value       = module.s3_images.bucket_domain_name
}

output "s3_images_folder_path" {
  description = "Recommended S3 path for storing images: s3://bucket-name/images/"
  value       = module.s3_images.images_folder_path
}

output "s3_images_cloudfront_domain" {
  description = "CloudFront domain name for distributing images globally"
  value       = module.s3_images.cloudfront_domain_name
}

output "s3_images_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for image cache invalidation"
  value       = module.s3_images.cloudfront_distribution_id
}

output "s3_images_url" {
  description = "Full URL to access images via CloudFront"
  value       = module.s3_images.images_url
}

# ============================================================
# S3 Frontend + CloudFront
# ============================================================

output "s3_frontend_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend application"
  value       = module.s3_frontend.bucket_name
}

output "s3_frontend_bucket_arn" {
  description = "ARN of the S3 frontend bucket"
  value       = module.s3_frontend.bucket_arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for accessing the frontend"
  value       = module.s3_frontend.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (use for cache invalidation)"
  value       = module.s3_frontend.cloudfront_distribution_id
}

output "frontend_url" {
  description = "Full URL to access the frontend application"
  value       = module.s3_frontend.frontend_url
}

# ============================================================
# Medusa Commerce Configuration
# ============================================================

output "medusa_api_url" {
  description = "Medusa Commerce API URL (access from frontend)"
  value       = "http://${module.ec2.public_ip}"
}

output "medusa_admin_dashboard_url" {
  description = "Medusa Commerce admin dashboard URL"
  value       = "http://${module.ec2.public_ip}/admin"
}

output "medusa_admin_email" {
  description = "Medusa Commerce administrator email"
  value       = var.medusa_admin_user
}

output "medusa_database_name" {
  description = "PostgreSQL database name for Medusa Commerce"
  value       = var.medusa_database_name
}

output "medusa_db_endpoint" {
  description = "RDS PostgreSQL endpoint for Medusa database connection"
  value       = try(module.rds[0].db_instance_endpoint, "NOT CREATED - enable_rds must be true")
  sensitive   = true
}

output "medusa_setup_instructions" {
  description = "Instructions to complete Medusa Commerce setup"
  value = format(<<-EOT
    Medusa Commerce Setup Instructions:
    
    1. Access Medusa API at: http://%s
    2. Access Admin Dashboard at: http://%s/admin
    3. Admin Email: %s
    4. Health Check: http://%s/health
    
    Database Connection Details:
    - Host: %s
    - Database: %s
    - User: postgres
    - Port: 5432
    
    Notes:
    - After installation, configure SSL/HTTPS with certbot
    - Run: ssh ec2-user@%s 'sudo certbot --nginx -d your-domain.com'
    - Update medusa_db_host variable with actual RDS endpoint after creation
    EOT
    , module.ec2.public_ip, module.ec2.public_ip, var.medusa_admin_user,
    module.ec2.public_ip, try(module.rds[0].db_instance_endpoint, "pending"),
    var.medusa_database_name, module.ec2.public_ip
  )
  sensitive = true
}



