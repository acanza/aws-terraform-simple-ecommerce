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
        # Confine the assume to this account only (confused-deputy mitigation)
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Custom inline policy instead of AWSAppRunnerServicePolicyForECRAccess.
# The AWS managed policy uses Resource: "*" for all ECR actions, which allows
# pulling from every repository in the account.
# Here we scope image-pull actions to the specific storefront repository ARN.
# ecr:GetAuthorizationToken must remain Resource: "*" (service-level API, not
# scoped to a repository by design).
resource "aws_iam_role_policy" "app_runner_ecr_pull" {
  name = "ecr-pull-storefront"
  role = aws_iam_role.app_runner_ecr_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECRImagePull"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeImages",
        ]
        # Scoped to this module's repository only — not account-wide
        Resource = aws_ecr_repository.storefront.arn
      },
      {
        Sid    = "AllowECRAuthToken"
        Effect = "Allow"
        # GetAuthorizationToken is a service-level call and cannot be
        # constrained to a specific resource ARN
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# App Runner auto-scaling configuration
# Created only when create_service = true (requires a Docker image in ECR)
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# VPC Connector – routes App Runner outbound traffic through the VPC
# Created only when enable_vpc_connector = true AND create_service = true.
# Use private subnets so internet-bound traffic exits via the NAT gateway.
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_apprunner_vpc_connector" "storefront" {
  count = var.create_service && var.enable_vpc_connector ? 1 : 0

  vpc_connector_name = local.service_name
  subnets            = var.subnet_ids
  security_groups    = [var.vpc_connector_security_group_id]

  tags = local.common_tags
}

resource "aws_apprunner_auto_scaling_configuration_version" "storefront" {
  count = var.create_service ? 1 : 0

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
  count = var.create_service ? 1 : 0

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
            # NEXT_PUBLIC_MEDUSA_BACKEND_URL: baked into JS bundle at build time (client-side)
            # MEDUSA_BACKEND_URL: read at runtime by Next.js middleware and server components
            # Both must point to the same backend — if only the build-arg is set, the
            # middleware will crash at startup trying to fetch regions from localhost:9000
            NEXT_PUBLIC_MEDUSA_BACKEND_URL = var.medusa_backend_url
            MEDUSA_BACKEND_URL             = var.medusa_backend_url
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

  # VPC Connector routes all outbound traffic through the VPC.
  # ingress remains public so end users can reach the storefront over HTTPS.
  # Only created when enable_vpc_connector = true.
  dynamic "network_configuration" {
    for_each = var.enable_vpc_connector ? [1] : []
    content {
      egress_configuration {
        egress_type       = "VPC"
        vpc_connector_arn = aws_apprunner_vpc_connector.storefront[0].arn
      }
      ingress_configuration {
        is_publicly_accessible = true
      }
    }
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.storefront[0].arn

  health_check_configuration {
    # TCP health check: only verifies port 8000 is accepting connections.
    # Using HTTP on / would trigger Next.js SSR which fetches from the Medusa
    # backend — if that fetch takes longer than the 5s timeout, App Runner marks
    # the deployment as failed even though the container is healthy.
    protocol            = "TCP"
    healthy_threshold   = 1
    interval            = 10
    timeout             = 5
    unhealthy_threshold = 5
  }

  tags = local.common_tags

  # ECR access role must be ready before App Runner tries to pull the image
  depends_on = [aws_iam_role_policy.app_runner_ecr_pull]
}
