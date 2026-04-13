variable "region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "eu-west-3"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "ecommerce"
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "trusted_ssh_cidr" {
  description = "CIDR block allowed for SSH access to EC2 instances (optional, SSH disabled if not provided)"
  type        = string
  default     = null
  validation {
    condition     = var.trusted_ssh_cidr == null || can(cidrhost(var.trusted_ssh_cidr, 0))
    error_message = "Trusted SSH CIDR must be a valid IPv4 CIDR block or null."
  }
}

variable "enable_http" {
  description = "Enable HTTP (port 80) access to EC2 instances from the internet"
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable HTTPS (port 443) access to EC2 instances from the internet"
  type        = bool
  default     = false
}

variable "db_port" {
  description = "Database port for RDS security group"
  type        = number
  default     = 3306
  validation {
    condition     = var.db_port >= 1024 && var.db_port <= 65535
    error_message = "Database port must be between 1024 and 65535."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
