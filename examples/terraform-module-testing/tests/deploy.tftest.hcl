# Test d'intégration : déployer l'exemple sur AWS reel (profil sandbox) et asserter
# les valeurs des ressources. terraform test detruit tout en fin de fichier.
# Requiert des credentials AWS (AWS_PROFILE=sandbox). Le suffixe aléatoire rend le
# nom de bucket globalement unique.

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
    error_message = "encryption must be off when no KMS key is provided"
  }
}
