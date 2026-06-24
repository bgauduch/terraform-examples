# Plan tests: prove that variables wire into the planned config.
# mock_provider -> no credential, fast, runs in CI without a secret.
# The file-level variables block sets defaults for EVERY run (live tip).

mock_provider "aws" {}

variables {
  bucket_name = "demo-plan-bucket"
  environment = "dev"
}

run "versioning_enabled_by_default" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "versioning should default to Enabled"
  }
}

run "public_access_fully_blocked" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.block_public_acls &&
      aws_s3_bucket_public_access_block.this.block_public_policy &&
      aws_s3_bucket_public_access_block.this.ignore_public_acls &&
      aws_s3_bucket_public_access_block.this.restrict_public_buckets
    )
    error_message = "all four public access block flags must be true"
  }
}

run "no_encryption_block_without_key" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  variables {
    enable_encryption = false
    kms_key_arn       = null
  }
  assert {
    condition     = length(aws_s3_bucket_server_side_encryption_configuration.this) == 0
    error_message = "encryption config must be absent when no KMS key is provided"
  }
}

run "encryption_block_present_with_key" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  variables {
    enable_encryption = true
    kms_key_arn       = "arn:aws:kms:eu-west-1:111122223333:key/demo-key"
  }
  assert {
    condition     = length(aws_s3_bucket_server_side_encryption_configuration.this) == 1
    error_message = "encryption config must be present when a KMS key is provided"
  }
  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this[0].rule).apply_server_side_encryption_by_default[0].kms_master_key_id == "arn:aws:kms:eu-west-1:111122223333:key/demo-key"
    error_message = "the provided KMS key ARN must propagate to the encryption rule"
  }
}
