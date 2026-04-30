locals {
  service_name  = "${var.project_name}-${var.environment}-storefront"
  ecr_repo_name = "${var.project_name}-${var.environment}-storefront"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "app-runner"
  })
}
