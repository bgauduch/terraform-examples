output "secret_arn" {
  description = "ARN of the secret. The consumer gets this, never the value."
  value       = aws_secretsmanager_secret.app.arn
}

output "fingerprint_command" {
  description = "Ready-to-paste command showing which value the consumer currently reads."
  value       = "aws lambda invoke --function-name ${aws_lambda_function.fingerprint.function_name} --region ${var.region} /dev/stdout"
}

output "state_proof_command" {
  description = "Ready-to-paste command showing what the state holds for the secret version."
  value       = "terraform state pull | jq '.resources[] | select(.type==\"aws_secretsmanager_secret_version\") | .instances[0].attributes | {secret_string, has_secret_string_wo, secret_string_wo_version}'"
}
