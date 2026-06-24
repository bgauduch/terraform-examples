# Parallelism: deploy the example twice in parallel without collision.
# Distinct state_key -> isolated state (1.11+); parallel = true runs them concurrently (1.12+).
# Requires AWS credentials (export AWS_PROFILE).

run "setup" {
  module {
    source = "./tests/setup"
  }
}

# Shared variables
variables {
  environment   = "dev"
  force_destroy = true
}

run "deploy_a" {
  command   = apply
  parallel  = true
  state_key = "a"
  variables {
    bucket_name = "bga-tftest-a-${run.setup.suffix}"
  }
  assert {
    condition     = output.bucket_id == "bga-tftest-a-${run.setup.suffix}"
    error_message = "bucket A name mismatch"
  }
}

run "deploy_b" {
  command   = apply
  parallel  = true
  state_key = "b"
  variables {
    bucket_name = "bga-tftest-b-${run.setup.suffix}"
  }
  assert {
    condition     = output.bucket_id == "bga-tftest-b-${run.setup.suffix}"
    error_message = "bucket B name mismatch"
  }
}
