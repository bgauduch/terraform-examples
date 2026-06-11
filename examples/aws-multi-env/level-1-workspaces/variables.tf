variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Project name used for tagging"
  type        = string
  default     = "demo-tf-multi-env"
}
