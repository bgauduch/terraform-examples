output "bucket_id" {
  description = "Name (ID) of the bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the bucket."
  value       = aws_s3_bucket.this.arn
}

output "versioning_status" {
  description = "Versioning status of the bucket."
  value       = aws_s3_bucket_versioning.this.versioning_configuration[0].status
}

output "encryption_enabled" {
  description = "Whether SSE-KMS encryption is configured."
  value       = local.kms_enabled
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption, or null when disabled."
  value       = var.kms_key_arn
}
