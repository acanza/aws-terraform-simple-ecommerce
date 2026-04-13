locals {
  common_tags = merge(
    {
      Name        = var.bucket_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "ecommerce"
    },
    var.tags
  )
}
