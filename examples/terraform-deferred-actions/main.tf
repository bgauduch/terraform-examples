# Demo: feed a KMS key ARN that is unknown at plan time into a generic S3 module.
# From Terraform 1.16 the module's count-driven data source is deferred to apply
# instead of failing the plan - the whole point of this example.

resource "random_id" "suffix" {
  byte_length = 4
}

# KMS key created in this root module; its ARN is unknown until apply.
resource "aws_kms_key" "root" {
  description             = "Root-managed KMS key for the deferred-actions S3 demo"
  deletion_window_in_days = 7
}

# Case 1 - encrypt with the root's KMS key. Its ARN is unknown at plan, so the
# module's data-source validation is deferred to apply.
module "existing_key_bucket" {
  source = "./modules/s3-bucket-encrypted"

  bucket_name = "${var.bucket_prefix}-existing-key-${random_id.suffix.hex}"
  kms_key_arn = aws_kms_key.root.arn
}

# Case 2 - no key provided: the module uses S3's default SSE-KMS managed key.
module "managed_key_bucket" {
  source = "./modules/s3-bucket-encrypted"

  bucket_name = "${var.bucket_prefix}-managed-key-${random_id.suffix.hex}"
}
