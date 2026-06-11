# AFTER (Terraform 1.16+): the KMS key ARN is unknown at plan, yet the module's
# count-driven data source no longer breaks the plan - run with `-allow-deferral`
# and Terraform defers it to apply (without the flag, the plan still errors).
# Single source of truth: just the ARN, no extra "is it provided?" flag.

resource "random_id" "suffix" {
  byte_length = 4
}

# KMS key created in this root module; its ARN is unknown until apply.
resource "aws_kms_key" "root" {
  description             = "Root-managed KMS key for the deferred-actions S3 demo"
  deletion_window_in_days = 7
}

module "bucket" {
  source = "./modules/s3-bucket-encrypted"

  bucket_name = "${var.bucket_prefix}-${random_id.suffix.hex}"
  kms_key_arn = aws_kms_key.root.arn
}
