output "bucket_id" {
  value = module.bucket.bucket_id
}

output "bucket_arn" {
  value = module.bucket.bucket_arn
}

output "versioning_status" {
  value = module.bucket.versioning_status
}

output "encryption_enabled" {
  value = module.bucket.encryption_enabled
}

output "kms_key_arn" {
  value = module.bucket.kms_key_arn
}
