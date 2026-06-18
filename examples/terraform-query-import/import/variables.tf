variable "region" {
  description = "AWS region to query for unmanaged resources"
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region identifier, e.g. eu-west-1."
  }

  nullable = false
}
