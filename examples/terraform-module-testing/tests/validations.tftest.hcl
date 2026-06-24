# Variable-validation tests (fail early, without touching AWS).
# command = plan: validation fails before any provider call -> creds-free.
# mock_provider as a safety net: guarantees no credential even if the plan proceeds.
# One atomic run per validator -> isolated error message, easy to read.

mock_provider "aws" {}

run "bucket_name_too_short" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  variables {
    bucket_name = "ab"
    environment = "dev"
  }
  expect_failures = [var.bucket_name]
}

run "bucket_name_invalid_chars" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  variables {
    bucket_name = "Mon_Bucket"
    environment = "dev"
  }
  expect_failures = [var.bucket_name]
}

run "invalid_environment" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  variables {
    bucket_name = "valid-bucket-name"
    environment = "production"
  }
  expect_failures = [var.environment]
}

run "encryption_requires_kms_key" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  variables {
    bucket_name       = "valid-bucket-name"
    environment       = "dev"
    enable_encryption = true
    kms_key_arn       = null
  }
  expect_failures = [var.enable_encryption]
}

run "prod_forbids_force_destroy" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  variables {
    bucket_name   = "valid-bucket-name"
    environment   = "prod"
    force_destroy = true
  }
  expect_failures = [var.force_destroy]
}

# Deny-by-default: staging is not in the allow-list either, so force_destroy is
# refused there too (the old blacklist on prod alone would have let this through).
run "staging_forbids_force_destroy" {
  command = plan
  module {
    source = "./modules/s3-bucket"
  }
  variables {
    bucket_name   = "valid-bucket-name"
    environment   = "staging"
    force_destroy = true
  }
  expect_failures = [var.force_destroy]
}
