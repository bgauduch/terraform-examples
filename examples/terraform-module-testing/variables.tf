variable "region" {
  description = "AWS region for the demo bucket."
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "Name of the demo bucket (globally unique)."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "enable_encryption" {
  description = "Enable SSE-KMS encryption."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow destroying a non-empty bucket (true in this demo for clean teardown)."
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = "Enable versioning."
  type        = bool
  default     = true
}

variable "run_id" {
  description = "Unique identifier for a test run, used for sweeper tagging."
  type        = string
  default     = "local"
}
