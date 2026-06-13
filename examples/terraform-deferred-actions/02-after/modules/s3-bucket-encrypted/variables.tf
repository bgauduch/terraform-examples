variable "bucket_name" {
  description = "Name of the S3 bucket to create."
  type        = string
}

variable "kms_key_arn" {
  description = <<-EOT
    ARN of an existing KMS key to encrypt the bucket with. When null, the bucket
    falls back to S3's default SSE-KMS managed key (aws/s3). The value may be
    unknown at plan time: the dependent data source and encryption config are then
    deferred to apply (Terraform 1.16+).
  EOT
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the bucket."
  type        = map(string)
  default     = {}
}
