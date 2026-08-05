output "key_arn" {
  description = "ARN of the demo KMS key"
  value       = aws_kms_key.app.arn
}

output "key_admin_principals" {
  description = "Principals granted administration on the key, as actually rendered for this account"
  value       = local.key_admin_principals
}

output "ops_role_detected" {
  description = "Whether the platform ops role was found in this account (what the check asserts on)"
  value       = length(local.ops_role_arns) > 0
}
