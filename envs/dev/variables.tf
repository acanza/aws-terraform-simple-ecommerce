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
  description = "Enable HTTP (port 80) to EC2 instances"
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable HTTPS (port 443) to EC2 instances"
  type        = bool
  default     = false
}

variable "db_port" {
  description = "Database port for RDS (default 3306 for MySQL, 5432 for PostgreSQL)"
  type        = number
  default     = 3306
}
