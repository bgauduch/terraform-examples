# count is keyed on the explicit, plan-known `var.kms.provided` flag - NOT on
# `var.kms.arn != null`, which would be unknown at plan and make `terraform plan`
# fail pre-1.16 ("Invalid count argument ... value depends on resource attributes
# that cannot be determined until apply"). That limitation is the whole reason the
# separate boolean exists.
data "aws_kms_key" "provided" {
  # DEMO segment 2 - starting point (1.15 OK): count keyed on the plan-known provided boolean.
  count = var.kms.provided ? 1 : 0
  # DEMO segment 2 - "it breaks": ARN unknown at plan -> Invalid count argument
  # count = var.kms.arn != null ? 1 : 0
  key_id = var.kms.arn
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
      # null => S3's default managed key (aws/s3); otherwise the validated ARN.
      kms_master_key_id = one(data.aws_kms_key.provided[*].arn)
    }
    bucket_key_enabled = true
  }
}
