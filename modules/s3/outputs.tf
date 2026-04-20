output "bucket_name" {
  description = "Nombre del bucket S3"
  value       = aws_s3_bucket.images.id
}

output "bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.images.arn
}

output "bucket_region" {
  description = "Región donde se encuentra el bucket"
  value       = aws_s3_bucket.images.region
}

output "bucket_domain_name" {
  description = "Nombre de dominio del bucket para acceso HTTP"
  value       = aws_s3_bucket.images.bucket_regional_domain_name
}

output "images_folder_path" {
  description = "Ruta recomendada para almacenar imágenes (s3://bucket-name/images/)"
  value       = "${aws_s3_bucket.images.id}/images/"
}

output "cloudfront_domain_name" {
  description = "Nombre de dominio de CloudFront para distribución de imágenes"
  value       = try(aws_cloudfront_distribution.images[0].domain_name, null)
}

output "cloudfront_distribution_id" {
  description = "ID de distribución CloudFront (para invalidación de caché)"
  value       = try(aws_cloudfront_distribution.images[0].id, null)
}

output "images_url" {
  description = "URL para acceder a las imágenes (CloudFront o S3)"
  value       = var.enable_cloudfront ? "https://${try(aws_cloudfront_distribution.images[0].domain_name, "")}" : "s3://${aws_s3_bucket.images.id}"
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
  description = "Prefix where images access logs are stored"
  value       = "images-access-logs/"
}
