# ─────────────────────────────────────────────────────────────────────────────
# ECR Repository – stores the Medusa Starter Storefront Docker image
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "storefront" {
  name = local.ecr_repo_name

  # MUTABLE allows pushing :latest without a new digest each time (acceptable for dev)
  image_tag_mutability = "MUTABLE"

  # Allow Terraform to delete the repository even if it still contains images
  # Assumption: safe only in non-prod environments
  force_delete = var.environment != "prod"

  image_scanning_configuration {
    # Scan every pushed image for known CVEs (no extra cost)
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "storefront" {
  repository = aws_ecr_repository.storefront.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the 5 most recent images to limit storage costs"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM – role that grants App Runner permission to pull images from ECR
# Principal: build.apprunner.amazonaws.com (image pull, not task execution)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "app_runner_ecr_access" {
  name = "${local.service_name}-ecr-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "build.apprunner.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "app_runner_ecr_readonly" {
  role       = aws_iam_role.app_runner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# ─────────────────────────────────────────────────────────────────────────────
# App Runner auto-scaling configuration
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_apprunner_auto_scaling_configuration_version" "storefront" {
  auto_scaling_configuration_name = local.service_name

  min_size        = var.min_size
  max_size        = var.max_size
  max_concurrency = var.max_concurrency

  tags = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# App Runner Service – runs the Next.js storefront container
#
# IMPORTANT – deployment order:
#   1. Apply with enable_app_runner = false  →  creates ECR repository only
#   2. Build & push Docker image:
#        docker build -t storefront ./storefront
#        docker tag storefront:latest <ecr_repository_url>:latest
#        aws ecr get-login-password | docker login --username AWS --password-stdin <ecr_repository_url>
#        docker push <ecr_repository_url>:latest
#   3. Set enable_app_runner = true and re-apply  →  creates App Runner service
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_apprunner_service" "storefront" {
  service_name = local.service_name

  source_configuration {
    # Grants App Runner the IAM role to authenticate against ECR
    authentication_configuration {
      access_role_arn = aws_iam_role.app_runner_ecr_access.arn
    }

    image_repository {
      image_configuration {
        port = tostring(var.port)

        runtime_environment_variables = merge(
          {
            # Standard env vars consumed by Medusa Starter Storefront
            NEXT_PUBLIC_MEDUSA_BACKEND_URL = var.medusa_backend_url
            NODE_ENV                       = "production"
          },
          var.env_vars
        )
      }

      image_identifier      = "${aws_ecr_repository.storefront.repository_url}:${var.image_tag}"
      image_repository_type = "ECR"
    }

    # Triggers a new deployment whenever a matching image tag is pushed to ECR
    auto_deployments_enabled = var.auto_deployments_enabled
  }

  instance_configuration {
    cpu    = var.cpu
    memory = var.memory
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.storefront.arn

  health_check_configuration {
    healthy_threshold   = 1
    interval            = 10
    path                = var.health_check_path
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 5
  }

  tags = local.common_tags

  # ECR access role must be attached before App Runner tries to pull the image
  depends_on = [aws_iam_role_policy_attachment.app_runner_ecr_readonly]
}
