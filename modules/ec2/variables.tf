variable "region" {
  description = "AWS region where the EC2 instance will be deployed"
  type        = string
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
}

variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "web-server"
}

variable "instance_type" {
  description = "EC2 instance type (use t4g.micro for cost optimization and ARM support, or t3.micro for x86)"
  type        = string
  default     = "t4g.micro"
  validation {
    condition     = can(regex("^t[34]g?\\.micro$", var.instance_type))
    error_message = "Instance type should be t3.micro, t4g.micro for cost optimization (free tier eligible)."
  }
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched (typically public subnet)"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to associate with the EC2 instance"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to EC2 instance for secure credential access (optional)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size in GiB (minimum 8 for Amazon Linux 2)"
  type        = number
  default     = 8
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 16384
    error_message = "Root volume size must be between 8 and 16384 GiB."
  }
}

variable "root_volume_type" {
  description = "EBS volume type for root volume (gp3 is default and cost effective)"
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2"], var.root_volume_type)
    error_message = "Volume type must be one of: gp3, gp2, io1, io2."
  }
}

variable "enable_ebs_optimization" {
  description = "Enable EBS optimization (may incur additional charges)"
  type        = bool
  default     = false
}

variable "associate_public_ip" {
  description = "Associate a public IP address with the instance"
  type        = bool
  default     = true
}

variable "monitoring_enabled" {
  description = "Enable detailed CloudWatch monitoring (may incur additional charges)"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "User data script to run on EC2 instance launch (optional)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
