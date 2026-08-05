# The website under observation, plus the precondition that gates what it serves.

# ---------------------------------------------------------------------------
# A public S3 static website. It is intentionally public so the check block can
# assert it over plain HTTP - see the README "Security baseline" section.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "site" {
  bucket = "${var.project}-${random_id.suffix.hex}"
  tags   = local.common_tags
}

# A static-website bucket is public by design, so the policy-related public-access
# guards are intentionally relaxed (ACL-based public access stays blocked). These
# two findings are the cost of a public website and are documented, not hidden.
#trivy:ignore:AVD-AWS-0093
#trivy:ignore:AVD-AWS-0087
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256) is fine for a public static website; a customer-managed KMS key
# (AVD-AWS-0132) adds no value for content that is served publicly anyway.
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public read of objects - this is the whole point of a static website bucket.
data "aws_iam_policy_document" "public_read" {
  statement {
    sid       = "PublicRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.public_read.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = local.index_html
  etag         = filemd5(local.index_html)
  content_type = "text/html"

  # A gate BEFORE publishing: the content we are about to ship has to carry the
  # marker the check asserts on afterwards. Same expectation as the check below,
  # enforced at a different moment - and this one blocks, by design.
  lifecycle {
    precondition {
      condition     = strcontains(file(local.index_html), local.health_marker)
      error_message = "content/index.html is missing the '${local.health_marker}' marker: publishing it would fail the health check on the next plan."
    }
  }
}
