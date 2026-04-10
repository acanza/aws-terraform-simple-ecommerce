# Data source to fetch the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-${var.instance_type == "t4g.micro" ? "arm64" : "x86_64"}-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# EC2 Instance - Minimal cost-optimized configuration
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile

  # Cost optimization settings
  associate_public_ip_address = var.associate_public_ip
  ebs_optimized               = var.enable_ebs_optimization
  monitoring                  = var.monitoring_enabled

  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true

    # Minimal encryption - use default AWS encryption to reduce complexity
    # For cost optimization, do not enable additional encryption overhead
    encrypted = false
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    {
      Name          = "${var.project_name}-${var.environment}-${var.instance_name}"
      Environment   = var.environment
      Project       = var.project_name
      ManagedBy     = "Terraform"
      CostOptimized = "true"
    },
    var.tags
  )

  lifecycle {
    ignore_changes = [ami]
  }
}
