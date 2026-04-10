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

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
