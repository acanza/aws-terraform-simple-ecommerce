# S3 bucket for hosting static frontend application
resource "aws_s3_bucket" "frontend" {
  bucket = var.bucket_name

  tags = local.common_tags
}

# Block public access initially (will be made public via bucket policy)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Enable versioning for rollback capability
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Website configuration for static hosting
resource "aws_s3_bucket_website_configuration" "frontend" {
  count = var.enable_cloudfront ? 0 : 1

  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }

  dynamic "routing_rule" {
    for_each = var.routing_rules != "" ? [1] : []

    content {
      redirect {
        replace_key_with = var.routing_rules
      }
    }
  }
}

# Bucket policy to allow public read access
data "aws_iam_policy_document" "frontend_policy" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    # Restrict to CloudFront if enabled
    dynamic "condition" {
      for_each = var.enable_cloudfront ? [1] : []

      content {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [aws_cloudfront_distribution.frontend[0].arn]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_policy.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# CloudFront Origin Access Control (OAC) for secure S3 access
resource "aws_cloudfront_origin_access_control" "s3" {
  count = var.enable_cloudfront ? 1 : 0

  name                              = "${local.s3_origin_id}-oac"
  description                       = "OAC for ${var.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution for global content delivery
resource "aws_cloudfront_distribution" "frontend" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.index_document
  price_class         = var.price_class

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3[0].id
    origin_id                = local.s3_origin_id
  }

  # Default cache behavior for HTML and other assets
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    default_ttl            = var.cache_ttl_default
    max_ttl                = var.cache_ttl_default * 2
  }

  # Specific cache behavior for HTML files (shorter TTL)
  cache_behavior {
    path_pattern     = "*.html"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    default_ttl            = var.cache_ttl_html
    max_ttl                = var.cache_ttl_html * 2
  }

  # Cache behavior for static assets (JS, CSS, images) - longer TTL
  cache_behavior {
    path_pattern     = "static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    compress               = true
    default_ttl            = 86400 * 30  # 30 days
    max_ttl                = 86400 * 365 # 365 days
  }

  viewer_certificate {
    cloudfront_default_certificate = !var.enable_ssl_certificate
    acm_certificate_arn            = var.enable_ssl_certificate ? var.ssl_certificate_arn : null
    ssl_support_method             = var.enable_ssl_certificate ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Custom error response for SPA routing
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/${var.index_document}"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/${var.index_document}"
    error_caching_min_ttl = 300
  }

  tags = local.common_tags
}

# Log bucket for CloudFront access logs (optional, for security audits)
resource "aws_s3_bucket" "frontend_logs" {
  count = var.enable_cloudfront ? 0 : 0 # Currently disabled, enable if needed

  bucket = "${var.bucket_name}-logs"

  tags = merge(
    local.common_tags,
    {
      Purpose = "CloudFront Logs"
    }
  )
}
