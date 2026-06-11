output "bucket_id" {
  description = "ID (name) of the created bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the created bucket."
  value       = aws_s3_bucket.this.arn
}

output "encryption_kms_key_arn" {
  description = "KMS key ARN used for encryption; null when using S3's default managed key."
  value       = one(data.aws_kms_key.provided[*].arn)
}
