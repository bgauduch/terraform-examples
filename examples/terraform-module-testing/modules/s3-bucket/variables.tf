variable "bucket_name" {
  description = "Name of the S3 bucket. Must follow S3 bucket naming rules."
  type        = string

  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "bucket_name must be between 3 and 63 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must start and end with a lowercase letter or digit and contain only lowercase letters, digits, dots and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "enable_encryption" {
  description = "Enable SSE-KMS encryption with a customer-managed key."
  type        = bool
  default     = false

  # Cross-variable validation (1.9+): enabling encryption requires a key.
  validation {
    condition     = !var.enable_encryption || var.kms_key_arn != null
    error_message = "kms_key_arn is required when enable_encryption is true."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for SSE-KMS. Required when enable_encryption is true."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow Terraform to destroy a non-empty bucket. Must stay false in prod."
  type        = bool
  default     = false

  # Cross-variable validation (1.9+): prod forbids force_destroy.
  validation {
    condition     = !(var.environment == "prod" && var.force_destroy)
    error_message = "force_destroy must be false when environment is prod."
  }
}

variable "versioning_enabled" {
  description = "Enable S3 bucket versioning."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to the bucket."
  type        = map(string)
  default     = {}
}
