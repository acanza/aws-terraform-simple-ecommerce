# Bucket S3 para almacenar imágenes de la aplicación
resource "aws_s3_bucket" "images" {
  bucket = var.bucket_name

  tags = local.common_tags
}

# Versionamiento para controlar versiones de imágenes
resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Encriptación del lado del servidor (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquear acceso público al bucket
resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = var.enable_cloudfront ? false : true
  block_public_policy     = var.enable_cloudfront ? false : true
  ignore_public_acls      = var.enable_cloudfront ? false : true
  restrict_public_buckets = var.enable_cloudfront ? false : true
}

# Política para otorgar permisos a roles específicos
data "aws_iam_policy_document" "bucket_policy" {
  # Permitir lecturas a roles especificados
  dynamic "statement" {
    for_each = length(var.read_access_role_arns) > 0 ? [1] : []

    content {
      sid    = "AllowReadAccess"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = var.read_access_role_arns
      }

      actions = [
        "s3:GetObject",
        "s3:ListBucket"
      ]

      resources = [
        aws_s3_bucket.images.arn,
        "${aws_s3_bucket.images.arn}/*"
      ]
    }
  }

  # Permitir escrituras a roles especificados
  dynamic "statement" {
    for_each = length(var.write_access_role_arns) > 0 ? [1] : []

    content {
      sid    = "AllowWriteAccess"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = var.write_access_role_arns
      }

      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]

      resources = [
        aws_s3_bucket.images.arn,
        "${aws_s3_bucket.images.arn}/*"
      ]
    }
  }

  # Denegar acceso no encriptado (obligar HTTPS)
  statement {
    sid    = "DenyUnencryptedTransport"
    effect = "Deny"

    principals = {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.images.arn,
      "${aws_s3_bucket.images.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# Aplicar la política al bucket
resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id
  policy = data.aws_iam_policy_document.bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.images]
}

# (Opcional) Ciclo de vida para limpiar objetos antiguos
resource "aws_s3_bucket_lifecycle_configuration" "images" {
  count  = var.lifecycle_expiration_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "expire-old-images"
    status = "Enabled"

    expiration {
      days = var.lifecycle_expiration_days
    }
  }
}

# ============================================================
# S3 ACCESS LOGGING
# ============================================================
# ✅ SECURITY FIX P1: Enable access logging for audit trail

resource "aws_s3_bucket" "logs" {
  bucket = "${var.bucket_name}-logs"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-logs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "images" {
  bucket = aws_s3_bucket.images.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "images-access-logs/"
}

# CloudFront Origin Access Control (OAC) para acceso seguro a S3
resource "aws_cloudfront_origin_access_control" "images" {
  count = var.enable_cloudfront ? 1 : 0

  name                              = "${var.bucket_name}-oac"
  description                       = "OAC para ${var.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Distribución CloudFront para distribución global de imágenes
resource "aws_cloudfront_distribution" "images" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  price_class         = var.cloudfront_price_class
  default_root_object = ""

  origin {
    domain_name              = aws_s3_bucket.images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.images[0].id
    origin_id                = "s3-images-origin"
  }

  # Comportamiento de caché por defecto para imágenes
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-images-origin"
    compress         = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    default_ttl            = var.cache_ttl_images
    max_ttl                = var.cache_ttl_images * 2
    min_ttl                = 0
  }

  # Restricciones geográficas (sin restricciones)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificado TLS
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = local.common_tags
}

# Política de bucket para permitir acceso desde CloudFront (OAC)
resource "aws_s3_bucket_policy" "images_cloudfront" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.images.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.images.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.images[0].arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.images]
}
