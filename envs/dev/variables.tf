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
