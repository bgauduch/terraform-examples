variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region identifier, e.g. eu-west-1."
  }

  nullable = false
}

variable "project" {
  description = "Project name used for the bucket name and tagging"
  type        = string
  default     = "demo-tf-check"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.project))
    error_message = "project must be 3-40 chars, lowercase letters, digits or hyphens (used as an S3 bucket prefix)."
  }

  nullable = false
}
