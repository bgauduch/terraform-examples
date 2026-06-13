# BEFORE (Terraform < 1.16): the KMS key ARN is unknown at plan, and count/for_each
# cannot depend on unknown values. So we cannot let the module derive "is a key
# provided?" from `arn != null`. We must thread a second, plan-known boolean
# (`provided`) alongside the ARN - redundant, and able to disagree with `arn`.

resource "random_id" "suffix" {
  byte_length = 4
}

# KMS key created in this root module; its ARN is unknown until apply.
resource "aws_kms_key" "root" {
  description = "Root-managed KMS key for the deferred-actions S3 demo (before)"
  # AWS-0065: enable annual rotation of the key material (security baseline).
  enable_key_rotation = true
  # AWS minimum; intentionally short here so the demo tears down quickly.
  deletion_window_in_days = 7
}

module "bucket" {
  source = "./modules/s3-bucket-encrypted"

  bucket_name = "${var.bucket_prefix}-${random_id.suffix.hex}"

  # `provided = true` is a literal known at plan -> the module's count is
  # determinable, even though `arn` itself is unknown until apply.
  kms = {
    arn      = aws_kms_key.root.arn
    provided = true
  }
}
