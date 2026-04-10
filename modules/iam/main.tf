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

# Policy for Terraform to manage infrastructure
resource "aws_iam_user_policy" "terraform_infrastructure" {
  name   = "${var.terraform_user_name}-infrastructure-policy"
  user   = aws_iam_user.terraform.name
  policy = data.aws_iam_policy_document.terraform_infrastructure.json
}

data "aws_iam_policy_document" "terraform_infrastructure" {
  # VPC Management
  statement {
    sid    = "AllowVPCManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:DescribeVpcs",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DescribeSubnets",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway",
      "ec2:DescribeInternetGateways",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:CreateRouteTable",
      "ec2:DescribeRouteTables",
      "ec2:DeleteRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateNatGateway",
      "ec2:DescribeNatGateways",
      "ec2:DeleteNatGateway",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:DescribeAddresses",
      "ec2:AllowSecurityGroupIngress"
    ]
    resources = ["*"]
  }

  # Security Groups Management
  statement {
    sid    = "AllowSecurityGroupManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:ModifySecurityGroupRules"
    ]
    resources = ["*"]
  }

  # EC2 Instance Management
  statement {
    sid    = "AllowEC2Management"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:DescribeInstances",
      "ec2:TerminateInstances",
      "ec2:RebootInstances",
      "ec2:StopInstances",
      "ec2:StartInstances",
      "ec2:ModifyInstanceAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeInstanceTypes",
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["*"]
  }

  # RDS Management
  statement {
    sid    = "AllowRDSManagement"
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance",
      "rds:DescribeDBInstances",
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",
      "rds:CreateDBSubnetGroup",
      "rds:DescribeDBSubnetGroups",
      "rds:DeleteDBSubnetGroup",
      "rds:DescribeDBSecurityGroups",
      "rds:CreateDBSnapshot",
      "rds:DescribeDBSnapshots",
      "rds:DeleteDBSnapshot",
      "rds:ListTagsForResource",
      "rds:AddTagsToResource"
    ]
    resources = ["*"]
  }

  # IAM Role Management (limited to project namespace)
  statement {
    sid    = "AllowIAMRoleManagement"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:DeleteRole",
      "iam:CreatePolicy",
      "iam:GetPolicy",
      "iam:DeletePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile"
    ]
    resources = [
      "arn:aws:iam::*:role/${local.namespace}-*",
      "arn:aws:iam::*:policy/${local.namespace}-*",
      "arn:aws:iam::*:instance-profile/${local.namespace}-*"
    ]
  }

  # Secrets Manager for RDS credentials
  statement {
    sid    = "AllowSecretsManagerManagement"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:ListSecrets",
      "secretsmanager:RestoreSecret",
      "secretsmanager:RotateSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:*:secret:${local.namespace}/*"
    ]
  }

  # KMS for encryption
  statement {
    sid    = "AllowKMSKeyManagement"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:ListKeys",
      "kms:TagResource",
      "kms:UntagResource"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:Description"
      values   = ["${local.namespace}*"]
    }
  }

  # S3 for Terraform state management
  statement {
    sid    = "AllowS3StateManagement"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${local.namespace}-terraform-state",
      "arn:aws:s3:::${local.namespace}-terraform-state/*"
    ]
  }

  # DynamoDB for Terraform state locking
  statement {
    sid    = "AllowDynamoDBStateLocking"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:*:table/${local.namespace}-terraform-lock"
    ]
  }

  # CloudWatch Logs for monitoring
  statement {
    sid    = "AllowCloudWatchLogsManagement"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup"
    ]
    resources = [
      "arn:aws:logs:${var.region}:*:log-group:/aws/ec2/${local.namespace}*",
      "arn:aws:logs:${var.region}:*:log-group:/aws/rds/${local.namespace}*"
    ]
  }
}

# ============================================================================
# IAM User for SSH Access to EC2 (Optional)
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
# IAM Group for read-only access (optional for additional users)
# ============================================================================

resource "aws_iam_group" "read_only" {
  name = "${local.namespace}-read-only"
}

resource "aws_iam_group_policy_attachment" "read_only_policy" {
  group      = aws_iam_group.read_only.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
