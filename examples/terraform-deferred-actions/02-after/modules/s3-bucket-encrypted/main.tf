locals {
  # When false, the bucket relies on S3's default SSE-KMS managed key (aws/s3).
  use_provided_key = var.kms_key_arn != null
}

# Validate the caller-provided key exists and is usable. Skipped entirely when no
# key is provided. When the ARN is unknown at plan time, this count is unknown and
# Terraform defers the data source to apply instead of failing the plan.
data "aws_kms_key" "provided" {
  count  = local.use_provided_key ? 1 : 0
  key_id = var.kms_key_arn
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      # one() => null (S3's default aws/s3 managed key) when no key was provided,
      # otherwise the validated ARN. Avoids indexing an empty count=0 tuple.
      kms_master_key_id = one(data.aws_kms_key.provided[*].arn)
      # DEMO segment 4 - one() pitfall: the naive ternary indexes provided[0] on a 0/unknown-length tuple -> Invalid index.
      # kms_master_key_id = local.use_provided_key ? data.aws_kms_key.provided[0].arn : null
    }
    bucket_key_enabled = true
  }
}
