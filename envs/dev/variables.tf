variable "region" {
  description = "AWS region for dev environment"
  type        = string
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  description = "CIDR block for development VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "trusted_ssh_cidr" {
  description = "CIDR block allowed for SSH access to EC2 (optional, SSH disabled if not provided)"
  type        = string
  default     = null
  validation {
    condition     = var.trusted_ssh_cidr == null || can(cidrhost(var.trusted_ssh_cidr, 0))
    error_message = "Trusted SSH CIDR must be a valid IPv4 CIDR block or null."
  }
}

variable "enable_http" {
  description = "Enable HTTP (port 80) to EC2 instances (required for Medusa)"
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Enable HTTPS (port 443) to EC2 instances (required for Medusa)"
  type        = bool
  default     = true
}

variable "db_port" {
  description = "Database port for RDS (default 3306 for MySQL, 5432 for PostgreSQL)"
  type        = number
  default     = 5432
}

variable "rds_master_password" {
  description = "Master password for RDS PostgreSQL database. Must be provided via terraform.tfvars (git-ignored). Never hardcode here."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.rds_master_password) >= 8 && length(var.rds_master_password) <= 128
    error_message = "RDS master password must be between 8 and 128 characters."
  }
}

variable "enable_rds" {
  description = "Enable RDS PostgreSQL database deployment"
  type        = bool
  default     = true
}

variable "medusa_database_name" {
  description = "Database name for Medusa Commerce backend"
  type        = string
  default     = "medusa"
  validation {
    condition     = can(regex("^[a-z0-9_]{1,63}$", var.medusa_database_name))
    error_message = "Database name must be lowercase alphanumeric with underscores, max 63 chars."
  }
}

variable "medusa_admin_user" {
  description = "Medusa administrator email/username"
  type        = string
  default     = "admin@medusa.local"
  validation {
    condition     = length(var.medusa_admin_user) >= 1 && length(var.medusa_admin_user) <= 60
    error_message = "Medusa admin user must be between 1 and 60 characters."
  }
}

variable "medusa_admin_password" {
  description = "Medusa administrator password (minimum 8 characters). Must be provided via terraform.tfvars (git-ignored). Never hardcode here."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.medusa_admin_password) >= 8 && length(var.medusa_admin_password) <= 255
    error_message = "Medusa admin password must be between 8 and 255 characters."
  }
}

variable "medusa_db_host" {
  description = "RDS database host/endpoint (will be set by outputs after RDS creation)"
  type        = string
  default     = "" # Will be overridden after RDS is created
}

variable "ec2_key_name" {
  description = "SSH key pair name for EC2 access (optional)"
  type        = string
  default     = null
}

variable "medusa_api_cidr" {
  description = "CIDR block allowed to reach the Medusa API on port 9000 (e.g. your workstation IP as x.x.x.x/32). Set to null to disable. Remove once VPC Connector is implemented."
  type        = string
  default     = null
  validation {
    condition     = var.medusa_api_cidr == null || can(cidrhost(var.medusa_api_cidr, 0))
    error_message = "medusa_api_cidr must be a valid IPv4 CIDR block or null."
  }
}

variable "enable_app_runner" {
  description = "Deploy App Runner service for the Medusa Starter Storefront (Next.js). Must push a Docker image to ECR before setting to true"
  type        = bool
  default     = false
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications via SNS. Set to null to create alarms without email subscription."
  type        = string
  default     = null
  validation {
    condition     = var.alarm_email == null || can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alarm_email))
    error_message = "alarm_email must be a valid email address or null."
  }
}
