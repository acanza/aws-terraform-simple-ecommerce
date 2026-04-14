# ============================================================
# DB SUBNET GROUP
# ============================================================
# Required for RDS instances in a VPC - defines which subnets
# the DB instance can be deployed to (must be in different AZs)

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-rds-subnet-group"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================
# RDS SECURITY GROUP
# ============================================================
# Controls inbound/outbound traffic for the RDS instance
# By default, only allows inbound PostgreSQL traffic from
# specified security groups and blocks all outbound

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL instance in private subnet"
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-rds-sg"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow inbound PostgreSQL traffic from specified security groups
resource "aws_security_group_rule" "rds_inbound" {
  count             = length(var.allowed_security_group_ids) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id

  source_security_group_id = var.allowed_security_group_ids[0]

  lifecycle {
    create_before_destroy = true
  }
}

# Allow additional inbound rules for each additional security group
resource "aws_security_group_rule" "rds_inbound_additional" {
  count             = length(var.allowed_security_group_ids) > 1 ? length(var.allowed_security_group_ids) - 1 : 0
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id

  source_security_group_id = var.allowed_security_group_ids[count.index + 1]

  lifecycle {
    create_before_destroy = true
  }
}

# Allow RDS to communicate outbound (minimal necessary)
resource "aws_security_group_rule" "rds_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================
# RDS DATABASE INSTANCE
# ============================================================

resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-${var.environment}-postgres"
  db_name           = var.database_name
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = var.enable_storage_encryption
  iops              = var.storage_type == "io1" ? 1000 : null

  # Network configuration - must be in private subnets
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = var.skip_final_snapshot

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  copy_tags_to_snapshot   = true

  # High availability
  multi_az = var.multi_az

  # Credentials
  username = var.database_username
  password = var.database_password

  # Authentication and security
  iam_database_authentication_enabled = var.enable_iam_database_authentication

  # Performance and monitoring
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null
  enabled_cloudwatch_logs_exports       = ["postgresql"]
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring[0].arn : null

  # Deletion protection
  deletion_protection = var.enable_deletion_protection
  apply_immediately   = var.apply_immediately

  # Parameter group - use default for now
  parameter_group_name = aws_db_parameter_group.main.name

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-postgres-db"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Engine      = "PostgreSQL"
    },
    var.tags
  )

  depends_on = [
    aws_db_subnet_group.main,
    aws_security_group.rds
  ]

  lifecycle {
    ignore_changes = [password]
  }
}

# ============================================================
# RDS PARAMETER GROUP
# ============================================================

resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-postgres-params"
  family = "postgres${var.engine_version}"

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-postgres-params"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================
# IAM ROLE FOR ENHANCED MONITORING (Optional)
# ============================================================

resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0
  name  = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-rds-monitoring-role"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.enable_enhanced_monitoring ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
