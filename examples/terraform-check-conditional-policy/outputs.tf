output "key_arn" {
  description = "ARN of the demo KMS key"
  value       = aws_kms_key.app.arn
}

output "bucket_name" {
  description = "Name of the bucket encrypted with the demo key"
  value       = aws_s3_bucket.data.id
}

output "key_admin_principals" {
  description = "Principals granted key administration, as actually rendered for this account"
  value       = local.key_admin_principals
}

output "baseline_roles_detected" {
  description = "Which baseline roles this account turned out to have"
  value = {
    platform_admin = length(local.platform_admin_arns) > 0
    break_glass    = length(local.break_glass_arns) > 0
  }
}
