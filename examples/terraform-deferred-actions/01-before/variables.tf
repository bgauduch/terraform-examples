variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region identifier, e.g. eu-west-1."
  }
}

variable "bucket_prefix" {
  description = "Prefix for the demo bucket name (a random suffix is appended for global uniqueness)."
  type        = string
  default     = "tf-deferred-demo-before"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}$", var.bucket_prefix))
    error_message = "bucket_prefix must be 2-41 chars of lowercase letters, digits or hyphens, starting with a letter or digit."
  }
}
