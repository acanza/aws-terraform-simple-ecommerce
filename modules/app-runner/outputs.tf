output "service_url" {
  description = "HTTPS URL of the Medusa Starter Storefront served by App Runner"
  value       = "https://${aws_apprunner_service.storefront.service_url}"
}

output "service_arn" {
  description = "ARN of the App Runner service"
  value       = aws_apprunner_service.storefront.arn
}

output "service_id" {
  description = "Unique identifier of the App Runner service"
  value       = aws_apprunner_service.storefront.service_id
}

output "ecr_repository_url" {
  description = "ECR repository URL – tag and push your Docker image here before enabling the service"
  value       = aws_ecr_repository.storefront.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.storefront.arn
}
