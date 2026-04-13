variable "region" {
  description = "AWS region for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod"
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
}

variable "ec2_instance_id" {
  description = "EC2 instance ID for IAM instance profile attachment"
  type        = string
  default     = ""
}

variable "rds_resource_arn" {
  description = "RDS database resource ARN for policy restrictions"
  type        = string
  default     = ""
}

variable "terraform_user_name" {
  description = "Username for Terraform/DevOps IAM user"
  type        = string
  default     = "terraform-admin"
}

variable "enable_ssh_user" {
  description = "Enable creation of dedicated SSH user for EC2 access"
  type        = bool
  default     = true
}

variable "ssh_user_name" {
  description = "Username for SSH access to EC2 instances"
  type        = string
  default     = "ec2-ssh-user"
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for images (optional, for EC2 instance role access)"
  type        = string
  default     = ""
}

variable "s3_frontend_bucket_arn" {
  description = "S3 bucket ARN for frontend (optional, for CI/CD pipeline access)"
  type        = string
  default     = ""
}

variable "enable_frontend_user" {
  description = "Enable creation of dedicated CI/CD user for frontend deployment"
  type        = bool
  default     = false
}

variable "frontend_user_name" {
  description = "Username for frontend CI/CD deployment"
  type        = string
  default     = "frontend-deployer"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
