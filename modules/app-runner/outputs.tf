output "service_url" {
  description = "HTTPS URL of the Medusa Starter Storefront served by App Runner (null if create_service = false)"
  value       = try(aws_apprunner_service.storefront[0].service_url, null)
}

output "service_arn" {
  description = "ARN of the App Runner service (null if create_service = false)"
  value       = try(aws_apprunner_service.storefront[0].arn, null)
}

output "service_id" {
  description = "Unique identifier of the App Runner service (null if create_service = false)"
  value       = try(aws_apprunner_service.storefront[0].service_id, null)
}

output "ecr_repository_url" {
  description = "ECR repository URL – tag and push your Docker image here before enabling the service"
  value       = aws_ecr_repository.storefront.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.storefront.arn
}
