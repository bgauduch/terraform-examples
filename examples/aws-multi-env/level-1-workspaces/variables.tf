variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region identifier, e.g. eu-west-1."
  }
}

variable "project" {
  description = "Project name used for tagging"
  type        = string
  default     = "demo-tf-multi-env"
  nullable    = false
}
