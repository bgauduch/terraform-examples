output "root_kms_key_arn" {
  description = "ARN of the KMS key created in the root module."
  value       = aws_kms_key.root.arn
}

output "existing_key_bucket" {
  description = "Bucket encrypted with the root-provided KMS key."
  value = {
    arn         = module.existing_key_bucket.bucket_arn
    kms_key_arn = module.existing_key_bucket.encryption_kms_key_arn
  }
}

output "managed_key_bucket" {
  description = "Bucket encrypted with S3's default SSE-KMS managed key."
  value = {
    arn         = module.managed_key_bucket.bucket_arn
    kms_key_arn = module.managed_key_bucket.encryption_kms_key_arn
  }
}
