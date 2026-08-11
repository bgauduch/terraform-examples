variable "region" {
  description = "AWS region for every resource in this example."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Name prefix for every resource, so the lab is easy to spot and to sweep."
  type        = string
  default     = "demo-tf-secrets"
}
