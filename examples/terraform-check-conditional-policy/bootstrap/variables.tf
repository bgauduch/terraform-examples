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

variable "platform_admin_role_name" {
  description = "Name of the platform administration role this baseline rolls out"
  type        = string
  default     = "demo-platform-admin"

  nullable = false
}

variable "break_glass_role_name" {
  description = "Name of the emergency access role this baseline rolls out"
  type        = string
  default     = "demo-break-glass"

  nullable = false
}
