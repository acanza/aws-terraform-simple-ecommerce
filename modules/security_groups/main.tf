# ============================================================
# EC2 SECURITY GROUP
# ============================================================

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for EC2 instances in public subnets"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-sg"
    }
  )
}

# Conditional: Inbound HTTP from internet (if enabled)
resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  count             = var.enable_http ? 1 : 0
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-http"
    }
  )
}

# Conditional: Inbound HTTPS from internet (if enabled)
resource "aws_vpc_security_group_ingress_rule" "ec2_https" {
  count             = var.enable_https ? 1 : 0
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-https"
    }
  )
}

# Conditional: Inbound Medusa API from internet (if enabled)
# Required for SSG during Docker builds and for dev storefront → backend calls
resource "aws_vpc_security_group_ingress_rule" "ec2_medusa_api" {
  count             = var.enable_medusa_api ? 1 : 0
  description       = "Medusa API (port 9000) from internet"
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-medusa-api"
    }
  )
}

# Conditional: Inbound SSH from trusted CIDR (if enabled)
resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  count             = var.trusted_ssh_cidr != null ? 1 : 0
  description       = "SSH from trusted CIDR"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.trusted_ssh_cidr
  security_group_id = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-ssh"
    }
  )
}

# ============================================================
# OUTBOUND (EGRESS) RULES - Restrict to necessary services
# ============================================================
# ✅ SECURITY FIX P1: Replace "allow all" with restrictive rules

# Outbound 1: Allow EC2 to RDS PostgreSQL (port 5432)
resource "aws_vpc_security_group_egress_rule" "ec2_to_rds" {
  description                  = "EC2 to RDS PostgreSQL"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id
  security_group_id            = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-to-rds"
    }
  )
}

# Outbound 2: Allow EC2 to S3 via HTTPS (port 443)
resource "aws_vpc_security_group_egress_rule" "ec2_to_s3" {
  description       = "EC2 to S3 via HTTPS for uploads/downloads"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-to-s3"
    }
  )
}

# Outbound 3: Allow EC2 to DNS (port 53 UDP)
resource "aws_vpc_security_group_egress_rule" "ec2_dns" {
  description       = "EC2 DNS resolution"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-dns"
    }
  )
}

# Outbound 4: Allow EC2 to Secrets Manager via HTTPS (port 443)
# ✅ NOTE: This rule may be redundant with ec2_to_s3 (also 0.0.0.0/0:443)
# Combined they provide both S3 and Secrets Manager access via HTTPS
resource "aws_vpc_security_group_egress_rule" "ec2_to_secrets" {
  description       = "EC2 to AWS Secrets Manager for RDS credentials"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-to-secrets"
    }
  )

  # ✅ WORKAROUND: If rule already exists in AWS, ignore the conflict
  lifecycle {
    ignore_changes = all
  }
}

# ============================================================
# RDS SECURITY GROUP
# ============================================================

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS instances in private subnets"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
    }
  )
}

# Inbound: Database access from EC2 security group only
resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  description                  = "Database access from EC2 instances"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2.id
  security_group_id            = aws_security_group.rds.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-from-ec2"
    }
  )
}

# Outbound: No outbound rules required for RDS (deny by default for database)
# Databases are inbound-only unless they need to reach external APIs
# If needed in future, add explicit rules here
