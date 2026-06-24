# Integration test: deploy the example on real AWS (sandbox profile) and assert
# the resource values. terraform test destroys everything at the end of the file.
# Requires AWS credentials (AWS_PROFILE=sandbox). The random suffix makes the
# bucket name globally unique.

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "deploy_and_assert" {
  command = apply

  variables {
    bucket_name        = "bga-tftest-${run.setup.suffix}"
    environment        = "dev"
    versioning_enabled = true
    force_destroy      = true
  }

  assert {
    condition     = output.bucket_id == "bga-tftest-${run.setup.suffix}"
    error_message = "deployed bucket id must match the requested name"
  }

  assert {
    condition     = output.versioning_status == "Enabled"
    error_message = "versioning must be Enabled on the deployed bucket"
  }

  assert {
    condition     = output.encryption_enabled == false
    error_message = "CMK encryption must be off (AWS-managed key fallback) when no key is provided"
  }
}
