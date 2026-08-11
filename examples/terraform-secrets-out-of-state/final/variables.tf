variable "region" {
  description = "AWS region for every resource in this module."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "demo-tf-secrets-final"
}

variable "secret_version" {
  description = <<-EOT
    Rotation trigger for the write-only argument. Increment to rotate: Terraform
    cannot diff a value it never stored, so the version is what signals intent.
    Keeping it in configuration makes every rotation a reviewed, attributable change.
  EOT
  type        = number
  default     = 1
}
