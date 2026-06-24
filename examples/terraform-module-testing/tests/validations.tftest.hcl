# Tests des validations de variables (échouer tôt, sans toucher AWS).
# command = plan : la validation échoue avant tout appel provider -> creds-free.
# mock_provider en filet : garantit l'absence de credential même si le plan progresse.
# Un run atomique par validateur -> message d'erreur isolé, relecture simple (tip live).

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
