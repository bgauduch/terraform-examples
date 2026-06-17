locals {
  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

# Random suffix so the (globally unique) bucket name does not collide between runs.
resource "random_id" "suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# Origin: a private S3 bucket, only reachable through CloudFront (OAC).
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "site" {
  bucket = "${var.project}-${random_id.suffix.hex}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256) is appropriate for public web assets served through a CDN.
# SSE-KMS with a customer-managed key would also require a KMS key policy granting
# the CloudFront OAC kms:Decrypt - out of scope for an actions-focused demo.
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# CloudFront distribution in front of the bucket, using Origin Access Control.
# ---------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project}-oac"
  description                       = "OAC for ${aws_s3_bucket.site.id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Managed cache policy - avoids the deprecated inline forwarded_values block.
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

# WAF, access logging and a custom TLS certificate are intentionally omitted to
# keep this a focused teaching demo - see the README "Security baseline" section.
#trivy:ignore:AVD-AWS-0011
#trivy:ignore:AVD-AWS-0010
#trivy:ignore:AVD-AWS-0013
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = "${var.project} - terraform actions demo"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags
}

# Bucket policy: only this CloudFront distribution (via OAC) may read objects.
data "aws_iam_policy_document" "site" {
  statement {
    sid       = "AllowCloudFrontOACRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

# ---------------------------------------------------------------------------
# The action: invalidate the CloudFront cache. Native AWS provider action
# (Terraform 1.14+), no Lambda or local-exec needed.
# ---------------------------------------------------------------------------
action "aws_cloudfront_create_invalidation" "invalidate" {
  config {
    distribution_id = aws_cloudfront_distribution.site.id
    paths           = ["/*"]
  }
}

# ---------------------------------------------------------------------------
# The page served by the CDN. Its lifecycle triggers the invalidation, so the
# new content is visible immediately instead of waiting for the cache to expire.
# ---------------------------------------------------------------------------
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${path.module}/content/index.html"
  etag         = filemd5("${path.module}/content/index.html")
  content_type = "text/html"

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_cloudfront_create_invalidation.invalidate]
    }
  }
}
