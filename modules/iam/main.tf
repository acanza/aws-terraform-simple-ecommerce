# ============================================================================
# EC2 IAM Role - Minimimum permissions for application servers
# ============================================================================

resource "aws_iam_role" "ec2_instance_role" {
  name               = "${local.namespace}-ec2-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Inline policy for EC2 to access Secrets Manager (RDS credentials)
resource "aws_iam_role_policy" "ec2_secrets_manager" {
  name   = "${local.namespace}-ec2-secrets-manager"
  role   = aws_iam_role.ec2_instance_role.id
  policy = data.aws_iam_policy_document.ec2_secrets_manager.json
}

data "aws_iam_policy_document" "ec2_secrets_manager" {
  statement {
    sid    = "AllowReadSecretsForRDS"
    effect = "Allow"
    # Restricted to secrets with specific naming pattern
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = ["arn:aws:secretsmanager:${var.region}:*:secret:${local.namespace}/rds/*"]
  }

  statement {
    sid    = "AllowDecryptSecretsWithKMS"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = ["arn:aws:kms:${var.region}:*:key/*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "secretsmanager.${var.region}.amazonaws.com"
      ]
    }
  }
}

# Policy for CloudWatch Logs
resource "aws_iam_role_policy" "ec2_cloudwatch_logs" {
  name   = "${local.namespace}-ec2-cloudwatch-logs"
  role   = aws_iam_role.ec2_instance_role.id
  policy = data.aws_iam_policy_document.ec2_cloudwatch_logs.json
}

data "aws_iam_policy_document" "ec2_cloudwatch_logs" {
  statement {
    sid    = "AllowCloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${var.region}:*:log-group:/aws/ec2/${local.namespace}*",
      "arn:aws:logs:${var.region}:*:log-group:/aws/ec2/${local.namespace}*:*"
    ]
  }
}

# Policy for S3 image bucket access (optional, if bucket ARN provided)
resource "aws_iam_role_policy" "ec2_s3_images" {
  count  = var.s3_bucket_arn != "" ? 1 : 0
  name   = "${local.namespace}-ec2-s3-images"
  role   = aws_iam_role.ec2_instance_role.id
  policy = data.aws_iam_policy_document.ec2_s3_images[0].json
}

data "aws_iam_policy_document" "ec2_s3_images" {
  count = var.s3_bucket_arn != "" ? 1 : 0

  statement {
    sid    = "AllowS3ImageBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AllowS3ImageBucketWrite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${var.s3_bucket_arn}/*"
    ]
  }
}

# EC2 Instance Profile for role attachment
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.namespace}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}

# ============================================================================
# IAM User for Terraform/DevOps - Restricted infrastructure management
# ============================================================================

resource "aws_iam_user" "terraform" {
  name = var.terraform_user_name
  tags = merge(
    local.common_tags,
    {
      Purpose = "Terraform Infrastructure Management"
    }
  )
}

# ✅ SECURITY FIX: 6 minimal inline policies (each < 2048 bytes)
# Policy 1: VPC only
resource "aws_iam_user_policy" "terraform_vpc" {
  name   = "${var.terraform_user_name}-vpc-policy"
  user   = aws_iam_user.terraform.name
  policy = data.aws_iam_policy_document.terraform_vpc.json
}

data "aws_iam_policy_document" "terraform_vpc" {
  statement {
    effect = "Allow"
    actions = ["ec2:CreateVpc", "ec2:DescribeVpcs", "ec2:DeleteVpc",
    "ec2:CreateSubnet", "ec2:DescribeSubnets", "ec2:DeleteSubnet",
    "ec2:CreateRouteTable", "ec2:DescribeRouteTables", "ec2:DeleteRouteTable",
    "ec2:CreateRoute", "ec2:DeleteRoute"]
    resources = ["*"]
  }
}

# Policy 2: Network infrastructure (IGW, NAT, routing)
resource "aws_iam_user_policy" "terraform_network" {
  name   = "${var.terraform_user_name}-network-policy"
  user   = aws_iam_user.terraform.name
  policy = data.aws_iam_policy_document.terraform_network.json
}

data "aws_iam_policy_document" "terraform_network" {
  statement {
    effect = "Allow"
    actions = ["ec2:CreateInternetGateway", "ec2:DescribeInternetGateways", "ec2:DeleteInternetGateway",
    "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
    "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
    "ec2:CreateNatGateway", "ec2:DescribeNatGateways", "ec2:DeleteNatGateway",
    "ec2:AllocateAddress", "ec2:ReleaseAddress"]
    resources = ["*"]
  }
}

# Policy 3: Security Groups
resource "aws_iam_user_policy" "terraform_sg" {
  name   = "${var.terraform_user_name}-sg-policy"
  user   = aws_iam_user.terraform.name
  policy = data.aws_iam_policy_document.terraform_sg.json
}

data "aws_iam_policy_document" "terraform_sg" {
  statement {
    effect = "Allow"
    actions = ["ec2:CreateSecurityGroup", "ec2:DescribeSecurityGroups", "ec2:DeleteSecurityGroup",
    "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
    "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress"]
    resources = ["*"]
  }
}

# Policy 4: Compute & DB
resource "aws_iam_user_policy" "terraform_compute_db" {
  name   = "${var.terraform_user_name}-compute-db-policy"
  user   = aws_iam_user.terraform.name
  policy = data.aws_iam_policy_document.terraform_compute_db.json
}

data "aws_iam_policy_document" "terraform_compute_db" {
  statement {
    effect = "Allow"
    actions = ["ec2:RunInstances", "ec2:TerminateInstances", "ec2:DescribeInstances", "ec2:DescribeImages",
    "ec2:CreateTags", "ec2:DeleteTags",
    "rds:CreateDBInstance", "rds:DeleteDBInstance", "rds:DescribeDBInstances",
    "rds:CreateDBSubnetGroup", "rds:DescribeDBSubnetGroups", "rds:DeleteDBSubnetGroup"]
    resources = ["*"]
  }
}

# Policy 5: IAM & S3
resource "aws_iam_user_policy" "terraform_iam_s3" {
  name   = "${var.terraform_user_name}-iam-s3-policy"
  user   = aws_iam_user.terraform.name
  policy = data.aws_iam_policy_document.terraform_iam_s3.json
}

data "aws_iam_policy_document" "terraform_iam_s3" {
  statement {
    effect = "Allow"
    actions = ["iam:CreateRole", "iam:DeleteRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
    "iam:PutRolePolicy", "iam:DeleteRolePolicy",
    "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
    "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile"]
    resources = ["arn:aws:iam::*:role/${local.namespace}-*", "arn:aws:iam::*:instance-profile/${local.namespace}-*"]
  }

  statement {
    effect = "Allow"
    actions = ["s3:CreateBucket", "s3:DeleteBucket", "s3:ListBucket", "s3:GetObject", "s3:PutObject",
    "s3:PutBucketPolicy", "s3:PutBucketVersioning", "s3:PutBucketServerSideEncryptionConfiguration",
    "s3:PutBucketPublicAccessBlock"]
    resources = ["arn:aws:s3:::${local.namespace}-*", "arn:aws:s3:::${local.namespace}-*/*"]
  }
}

# Policy 6: Secrets, KMS, DynamoDB, Logs
resource "aws_iam_user_policy" "terraform_secrets_logs" {
  name   = "${var.terraform_user_name}-secrets-logs-policy"
  user   = aws_iam_user.terraform.name
  policy = data.aws_iam_policy_document.terraform_secrets_logs.json
}

data "aws_iam_policy_document" "terraform_secrets_logs" {
  statement {
    effect = "Allow"
    actions = ["secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
    "kms:Decrypt", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem",
    "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy"]
    resources = ["arn:aws:secretsmanager:${var.region}:*:secret:${local.namespace}/*",
      "arn:aws:dynamodb:${var.region}:*:table/${local.namespace}-terraform-lock",
      "arn:aws:logs:${var.region}:*:log-group:/aws/*/${local.namespace}*"]
  }
}

# ============================================================================
# IAM User for SSH/EC2 Session Manager Access (Optional)
# ============================================================================

resource "aws_iam_user" "ssh_user" {
  count = var.enable_ssh_user ? 1 : 0
  name  = var.ssh_user_name
  tags = merge(
    local.common_tags,
    {
      Purpose = "SSH Access to EC2"
    }
  )
}

# Policy for SSH/System Manager access
resource "aws_iam_user_policy" "ssh_user_policy" {
  count  = var.enable_ssh_user ? 1 : 0
  name   = "${var.ssh_user_name}-ssm-policy"
  user   = aws_iam_user.ssh_user[0].name
  policy = data.aws_iam_policy_document.ssh_user_policy[0].json
}

data "aws_iam_policy_document" "ssh_user_policy" {
  count = var.enable_ssh_user ? 1 : 0

  # Systems Manager for session access (alternative to SSH)
  statement {
    sid    = "AllowSSMSessionManager"
    effect = "Allow"
    actions = [
      "ssm:StartSession",
      "ssm:TerminateSession",
      "ssm:ResumeSession",
      "ssm:DescribeDocument",
      "ssm:GetDocument"
    ]
    resources = [
      "arn:aws:ec2:${var.region}:*:instance/*"
    ]
    condition {
      test     = "StringLike"
      variable = "aws:userid"
      values   = ["AIDAI*"]
    }
  }

  # EC2 instance lookup
  statement {
    sid    = "AllowEC2InstanceLookup"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs for session recording
  statement {
    sid    = "AllowSSMCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.region}:*:log-group:/aws/ssm/session-${local.namespace}:*"
    ]
  }

  # S3 for session logs
  statement {
    sid    = "AllowSSMLogStorage"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${local.namespace}-ssm-session-logs/*"
    ]
  }
}

# ============================================================================
# IAM User for Frontend CI/CD Deployment (Optional)
# ============================================================================

resource "aws_iam_user" "frontend_deployer" {
  count = var.enable_frontend_user ? 1 : 0
  name  = var.frontend_user_name
  tags = merge(
    local.common_tags,
    {
      Purpose = "Frontend CI/CD Deployment"
    }
  )
}

# Policy for frontend bucket deployment
resource "aws_iam_user_policy" "frontend_deployer_policy" {
  count  = var.enable_frontend_user ? 1 : 0
  name   = "${var.frontend_user_name}-s3-policy"
  user   = aws_iam_user.frontend_deployer[0].name
  policy = data.aws_iam_policy_document.frontend_deployer_policy[0].json
}

data "aws_iam_policy_document" "frontend_deployer_policy" {
  count = var.enable_frontend_user ? 1 : 0

  # List frontend bucket
  statement {
    sid    = "AllowFrontendBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions"
    ]
    resources = [
      "arn:aws:s3:::${local.namespace}-frontend*"
    ]
  }

  # Upload/delete objects in frontend bucket (with version control)
  statement {
    sid    = "AllowFrontendObjectDeployment"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${local.namespace}-frontend*/*"
    ]
  }

  # Invalidate CloudFront cache (if CloudFront is enabled)
  statement {
    sid    = "AllowCloudFrontInvalidation"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:ListInvalidations",
      "cloudfront:GetInvalidation"
    ]
    resources = [
      "arn:aws:cloudfront::*:distribution/*"
    ]
    condition {
      test     = "StringLike"
      variable = "aws:userid"
      values   = ["*${local.namespace}*"]
    }
  }

  # Read CloudFront distributions (for determining distribution ID)
  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"
    actions = [
      "cloudfront:ListDistributions",
      "cloudfront:GetDistribution"
    ]
    resources = ["*"]
  }
}

# ============================================================================
# IAM Group for read-only access (optional for additional users)
# ============================================================================

resource "aws_iam_group" "read_only" {
  name = "${local.namespace}-read-only"
}

resource "aws_iam_group_policy_attachment" "read_only_policy" {
  group      = aws_iam_group.read_only.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
