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
  description = "Project name used for the KMS alias, the bucket name and tagging"
  type        = string
  default     = "demo-tf-check-policy"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.project))
    error_message = "project must be 3-40 chars, lowercase letters, digits or hyphens (used as an S3 bucket prefix)."
  }

  nullable = false
}

variable "platform_admin_role_name" {
  description = <<-EOT
    Platform administration role. Managed by `bootstrap/`, not here. Accounts mid-migration
    legitimately lack it, so its absence is reported by a check and the apply proceeds.
  EOT
  type        = string
  default     = "demo-platform-admin"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.platform_admin_role_name))
    error_message = "platform_admin_role_name must be a valid IAM role name (1-64 chars, [A-Za-z0-9+=,.@_-])."
  }

  nullable = false
}

variable "break_glass_role_name" {
  description = <<-EOT
    Emergency access role. Managed by `bootstrap/`, not here. Policy calls for a named,
    audited emergency path on a key of this class, so its absence blocks the apply through
    a precondition rather than merely warning.
  EOT
  type        = string
  default     = "demo-break-glass"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.break_glass_role_name))
    error_message = "break_glass_role_name must be a valid IAM role name (1-64 chars, [A-Za-z0-9+=,.@_-])."
  }

  nullable = false
}

variable "permanent_admin_role_name" {
  description = <<-EOT
    The one administrator granted unconditionally, with no lookup behind it: every account has
    it, so the key always has an owner. Its counterpart is the conditional pair above, which is
    where the interesting decisions live.
  EOT
  type        = string
  default     = "OrganizationAccountAccessRole"

  nullable = false
}

variable "enable_org_deny" {
  description = <<-EOT
    Add the `DenyOutsideOrganization` statement. A Deny in a key policy also governs who may
    edit that policy, so a miscalibrated condition leaves the key unrecoverable - keep this
    switch reachable rather than inlining the statement.
  EOT
  type        = bool
  default     = true

  nullable = false
}
