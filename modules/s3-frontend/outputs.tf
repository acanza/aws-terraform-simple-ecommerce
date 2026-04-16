output "bucket_name" {
  description = "Name of the S3 bucket hosting the frontend"
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.frontend.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = try(aws_cloudfront_distribution.frontend[0].domain_name, null)
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = try(aws_cloudfront_distribution.frontend[0].id, null)
}

output "frontend_url" {
  description = "Full URL to access the frontend application"
  value       = var.enable_cloudfront ? try("https://${aws_cloudfront_distribution.frontend[0].domain_name}", null) : try("http://${aws_s3_bucket_website_configuration.frontend[0].website_endpoint}", null)
}

# ============================================================
# S3 ACCESS LOGGING OUTPUTS
# ============================================================

output "logs_bucket_name" {
  description = "S3 bucket name for access logs"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "S3 bucket ARN for access logs"
  value       = aws_s3_bucket.logs.arn
}

output "logs_prefix" {
  description = "Prefix where frontend access logs are stored"
  value       = "frontend-access-logs/"
}
