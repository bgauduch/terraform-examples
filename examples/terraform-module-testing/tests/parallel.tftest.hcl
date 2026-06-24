# Parallélisme : déployer l'exemple deux fois en parallèle sans collision.
# state_key distinct -> état isolé -> les runs s'exécutent concurremment (>= 1.12).
# Requiert des credentials AWS (AWS_PROFILE=sandbox).

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "deploy_a" {
  command   = apply
  parallel  = true
  state_key = "a"
  variables {
    bucket_name   = "bga-tftest-a-${run.setup.suffix}"
    environment   = "dev"
    force_destroy = true
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
    bucket_name   = "bga-tftest-b-${run.setup.suffix}"
    environment   = "dev"
    force_destroy = true
  }
  assert {
    condition     = output.bucket_id == "bga-tftest-b-${run.setup.suffix}"
    error_message = "bucket B name mismatch"
  }
}
