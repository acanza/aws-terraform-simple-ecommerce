locals {
  common_tags = merge(
    {
      Name        = var.bucket_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "ecommerce"
      Component   = "frontend"
    },
    var.tags
  )

  # CloudFront origin ID
  s3_origin_id = "s3-frontend-origin"
}
