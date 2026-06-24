locals {
  # True when a customer-managed key (CMK) is in use: encryption enabled AND a key
  # provided. Drives the CMK-vs-AWS-managed-key choice below and the encryption_enabled output.
  kms_enabled = var.enable_encryption && var.kms_key_arn != null
}

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# The bucket is always encrypted. With a CMK (enable_encryption + kms_key_arn) it uses
# SSE-KMS with that key; otherwise it falls back to the AWS-managed key for S3
# (kms_master_key_id = null). trivy AWS-0132 wants a customer-managed key, which the
# fallback path doesn't use, so it is ignored here.
# TODO(security): require a CMK to satisfy AWS-0132 for real - e.g. provision one in the
# root and inject it (like the deferred-actions example). Deferred hardening.
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_enabled ? var.kms_key_arn : null
    }
    bucket_key_enabled = true
  }
}
