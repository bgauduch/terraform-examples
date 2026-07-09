variable "region" {
  description = "AWS region for every resource. Kept to eu-west-1 to match the sandbox region-lock SCP."
  type        = string
  default     = "eu-west-1"
}

variable "mgmt_profile" {
  description = "AWS CLI/SSO profile for the org management (payer) account: Organizations SCPs + Budgets."
  type        = string
}

variable "sandbox_profile" {
  description = "AWS CLI/SSO profile for the sandbox member account: runaway resource + remediation stack."
  type        = string
}

variable "mgmt_account_id" {
  description = "Org management account ID (12 digits)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.mgmt_account_id))
    error_message = "mgmt_account_id must be exactly 12 digits."
  }
}

variable "sandbox_account_id" {
  description = "Sandbox member account ID (12 digits) - the cut-off target."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.sandbox_account_id))
    error_message = "sandbox_account_id must be exactly 12 digits."
  }
}

variable "break_glass_role_name" {
  description = "Name of a break-glass IAM role in the sandbox account, spared by every cut-off SCP (anti-lock-out)."
  type        = string
  default     = "break-glass-admin"
}

variable "notify_email" {
  description = "Email address that receives the budget notification and the remediation confirmation."
  type        = string

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", var.notify_email))
    error_message = "notify_email must be a valid email address."
  }
}

variable "budget_limit_usd" {
  description = "Monthly cost budget limit in USD. Kept tiny so real spend already exceeds it (arms the action pre-live)."
  type        = string
  default     = "0.01"
}

variable "runaway_instance_type" {
  description = "Instance type of the demo runaway EC2 (the resource that 'burns money'). Kept cheap."
  type        = string
  default     = "t3.micro"
}
