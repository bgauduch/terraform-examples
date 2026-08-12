output "secret_arn" {
  description = "ARN of the secret. The consumer gets this, never the value."
  value       = aws_secretsmanager_secret.app.arn
}

output "fingerprint_command" {
  description = "Ready-to-paste command showing which value the consumer currently reads."
  # Payload to a file, not /dev/stdout: the CLI writes its own metadata there too, and
  # the two collide on screen. One file, then the payload alone, pretty-printed.
  value = "aws lambda invoke --function-name ${aws_lambda_function.fingerprint.function_name} --region ${var.region} /tmp/fingerprint.json > /dev/null && jq . /tmp/fingerprint.json"
}

output "state_proof_command" {
  description = "Ready-to-paste command showing what the state holds for the secret version."
  # `--arg` keeps escaped quotes out of the value, so the command survives a copy-paste.
  value = "terraform state pull | jq --arg t aws_secretsmanager_secret_version '.resources[] | select(.type==$t) | .instances[0].attributes | {secret_string, has_secret_string_wo, secret_string_wo_version}'"
}
