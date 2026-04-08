variable "aws_region" {
  description = "AWS region for RDS instance"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{1,30}$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, max 30 chars."
  }
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "14"
  validation {
    condition     = contains(["13", "14", "15", "16"], var.engine_version)
    error_message = "Engine version must be 13, 14, 15, or 16."
  }
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition     = can(regex("^db\\.t[34]\\.(micro|small|medium|large)$", var.instance_class))
    error_message = "Instance class must be a valid db.t3 or db.t4 type."
  }
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1)"
  type        = string
  default     = "gp2"
  validation {
    condition     = contains(["gp2", "gp3", "io1"], var.storage_type)
    error_message = "Storage type must be gp2, gp3, or io1."
  }
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 1 and 35 days."
  }
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS deployment"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for RDS."
  }
}

variable "allowed_security_group_ids" {
  description = "Security group IDs that can access the RDS instance"
  type        = list(string)
  default     = []
}

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = "ecommerce"
  validation {
    condition     = can(regex("^[a-z0-9_]{1,63}$", var.database_name))
    error_message = "Database name must be lowercase alphanumeric with underscores, max 63 chars."
  }
}

variable "database_username" {
  description = "Master username for RDS (use Secrets Manager instead of hardcoding)"
  type        = string
  sensitive   = true
  default     = "postgres"
  validation {
    condition     = can(regex("^[a-z0-9_]{1,16}$", var.database_username))
    error_message = "Username must be lowercase alphanumeric with underscores, 1-16 chars."
  }
}

variable "database_password" {
  description = "Master password for RDS - should be managed via Secrets Manager in production"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.database_password) >= 8 && length(var.database_password) <= 128
    error_message = "Password must be between 8 and 128 characters."
  }
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (NOT recommended for production)"
  type        = bool
  default     = false
}

variable "enable_storage_encryption" {
  description = "Enable storage encryption at rest"
  type        = bool
  default     = true
}

variable "enable_iam_database_authentication" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = true
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "The interval, in seconds, to collect enhanced monitoring metrics (0 to disable)"
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection to prevent accidental deletion"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately or wait for maintenance window"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
