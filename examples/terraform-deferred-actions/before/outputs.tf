output "root_kms_key_arn" {
  description = "ARN of the KMS key created in the root module."
  value       = aws_kms_key.root.arn
}

output "bucket" {
  description = "Bucket encrypted with the root-created KMS key."
  value = {
    arn         = module.bucket.bucket_arn
    kms_key_arn = module.bucket.encryption_kms_key_arn
  }
}
