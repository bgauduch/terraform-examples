output "secret_arn" {
  description = "Hand this to consumers. The value itself never leaves the vault."
  value       = aws_secretsmanager_secret.app.arn
}

output "state_proof_command" {
  description = "Shows what the state holds: a flag and a version, never the value."
  value       = "terraform state pull | jq '.resources[] | select(.type==\"aws_secretsmanager_secret_version\") | .instances[0].attributes | {secret_string, has_secret_string_wo, secret_string_wo_version}'"
}
