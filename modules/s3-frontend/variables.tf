variable "bucket_name" {
  description = "Name of the S3 bucket for hosting the frontend application"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9\\-]{3,63}$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "environment" {
  description = "Environment (dev, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, or prod."
  }
}

variable "domain_name" {
  description = "Custom domain name for CloudFront distribution (optional)"
  type        = string
  default     = ""
}

variable "index_document" {
  description = "Index document for website hosting (typically index.html)"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Error document for 404 responses (typically index.html for SPAs)"
  type        = string
  default     = "index.html"
}

variable "routing_rules" {
  description = "JSON routing rules for website configuration (for SPAs, redirect 404 to index.html)"
  type        = string
  default     = ""
}

variable "enable_cloudfront" {
  description = "Enable CloudFront distribution for the frontend"
  type        = bool
  default     = true
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "Price class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "cache_ttl_default" {
  description = "Default cache TTL in seconds for CloudFront"
  type        = number
  default     = 3600 # 1 hour

  validation {
    condition     = var.cache_ttl_default >= 0
    error_message = "Cache TTL must be >= 0."
  }
}

variable "cache_ttl_html" {
  description = "Cache TTL for HTML files (index.html) in seconds"
  type        = number
  default     = 300 # 5 minutes

  validation {
    condition     = var.cache_ttl_html >= 0
    error_message = "HTML cache TTL must be >= 0."
  }
}

variable "enable_ssl_certificate" {
  description = "Enable HTTPS with SSL/TLS certificate (requires domain_name and ACM certificate)"
  type        = bool
  default     = false
}

variable "ssl_certificate_arn" {
  description = "ARN of the ACM SSL certificate (required if enable_ssl_certificate is true)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for the bucket and distribution"
  type        = map(string)
  default     = {}
}
