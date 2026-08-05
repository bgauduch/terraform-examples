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
  description = "Project name used for the KMS alias and tagging"
  type        = string
  default     = "demo-tf-check-policy"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.project))
    error_message = "project must be 3-40 chars, lowercase letters, digits or hyphens (used as a KMS alias suffix)."
  }

  nullable = false
}

variable "ops_role_name" {
  description = <<-EOT
    Name of the platform-owned operations role that should hold KMS administration
    rights. It is NOT managed here: another stack (or another team) rolls it out per
    account, so it legitimately exists in some environments and not in others.
  EOT
  type        = string
  default     = "demo-ops-admin"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.ops_role_name))
    error_message = "ops_role_name must be a valid IAM role name (1-64 chars, [A-Za-z0-9+=,.@_-])."
  }

  nullable = false
}
