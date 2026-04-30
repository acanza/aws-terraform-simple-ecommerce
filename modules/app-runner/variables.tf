variable "project_name" {
  description = "Project name used as prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, stage, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "medusa_backend_url" {
  description = "URL of the Medusa Commerce backend API passed as NEXT_PUBLIC_MEDUSA_BACKEND_URL (e.g. http://1.2.3.4)"
  type        = string
}

variable "port" {
  description = "Port the Next.js storefront listens on. Medusa Starter Storefront default is 8000"
  type        = number
  default     = 8000
  validation {
    condition     = var.port > 0 && var.port < 65536
    error_message = "Port must be between 1 and 65535."
  }
}

variable "cpu" {
  description = "vCPU allocation for each App Runner instance. Valid: 256 (0.25), 512 (0.5), 1024 (1), 2048 (2), 4096 (4)"
  type        = string
  default     = "512"
  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Memory allocation in MB for each App Runner instance. Must be compatible with cpu (512→512|1024, 1024→1024|2048, etc.)"
  type        = string
  default     = "1024"
  validation {
    condition     = contains(["512", "1024", "2048", "3072", "4096", "6144", "8192", "10240", "12288"], var.memory)
    error_message = "Memory must be a valid App Runner value in MB."
  }
}

variable "image_tag" {
  description = "Docker image tag to deploy from ECR"
  type        = string
  default     = "latest"
}

variable "create_service" {
  description = "Create the App Runner service. Set to false on the first apply (only ECR + IAM will be created); set to true after pushing a Docker image to ECR"
  type        = bool
  default     = false
}

variable "auto_deployments_enabled" {
  description = "Automatically redeploy the service when a new image is pushed to ECR"
  type        = bool
  default     = true
}

variable "min_size" {
  description = "Minimum number of App Runner instances (minimum is 1; there is no scale-to-zero)"
  type        = number
  default     = 1
  validation {
    condition     = var.min_size >= 1
    error_message = "App Runner minimum instance count is 1."
  }
}

variable "max_size" {
  description = "Maximum number of App Runner instances. Keep at 1 for dev to control costs"
  type        = number
  default     = 1
  validation {
    condition     = var.max_size >= 1 && var.max_size <= 25
    error_message = "Max size must be between 1 and 25."
  }
}

variable "max_concurrency" {
  description = "Maximum concurrent requests per instance before a new instance is added"
  type        = number
  default     = 100
}

variable "health_check_path" {
  description = "HTTP path used by App Runner for health checks"
  type        = string
  default     = "/"
}

variable "env_vars" {
  description = "Additional environment variables to inject into the Next.js container (do NOT store secrets here)"
  type        = map(string)
  default     = {}
}

# ── VPC Connector (optional) ──────────────────────────────────────────────────
# When enable_vpc_connector = true, App Runner routes all outbound traffic
# through the VPC. Required to reach EC2 on port 9000 without exposing it
# to the internet. subnet_ids should be private subnets (for NAT gateway
# access to the internet). vpc_connector_security_group_id must allow egress
# to EC2:9000 and internet:443.

variable "enable_vpc_connector" {
  description = "Route App Runner outbound traffic through the VPC. Required to reach EC2 on port 9000 without opening it to the internet."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the VPC Connector. Use private subnets so internet-bound traffic exits via NAT gateway."
  type        = list(string)
  default     = []
  validation {
    condition     = !var.enable_vpc_connector || length(var.subnet_ids) > 0
    error_message = "subnet_ids must be provided when enable_vpc_connector is true."
  }
}

variable "vpc_connector_security_group_id" {
  description = "ID of the security group to attach to the VPC Connector. Must allow egress to EC2:9000 and internet:443."
  type        = string
  default     = null
  validation {
    condition     = !var.enable_vpc_connector || var.vpc_connector_security_group_id != null
    error_message = "vpc_connector_security_group_id must be provided when enable_vpc_connector is true."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
