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

# Outbound: Allow all traffic (EC2 needs to reach RDS, S3, NAT gateway, etc.)
resource "aws_vpc_security_group_egress_rule" "ec2_all_outbound" {
  description       = "Allow all outbound traffic (to RDS, S3, internet, etc.)"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-out-all"
    }
  )
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
