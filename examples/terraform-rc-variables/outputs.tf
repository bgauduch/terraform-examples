output "kms_key_arn" {
  description = "The KMS key ARN forwarded to the consuming module (may be unknown at plan)."
  value       = local.kms_key_arn
}
