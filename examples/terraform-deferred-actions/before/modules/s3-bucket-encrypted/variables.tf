variable "bucket_name" {
  description = "Name of the S3 bucket to create."
  type        = string
}

variable "kms" {
  description = <<-EOT
    KMS settings for bucket encryption. Pre-1.16, `provided` (a value known at
    plan time) is REQUIRED separately from `arn` (which may be unknown at plan):
    count/for_each cannot depend on unknown values, so the module cannot infer
    "is a key provided?" from `arn != null`. When `provided` is false the bucket
    falls back to S3's default SSE-KMS managed key (aws/s3).
  EOT
  type = object({
    arn      = optional(string)
    provided = bool
  })
  default = {
    arn      = null
    provided = false
  }
}

variable "tags" {
  description = "Tags to apply to the bucket."
  type        = map(string)
  default     = {}
}
