variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project" {
  description = "Project name used for tagging"
  type        = string
  default     = "demo-tf-multi-env"
}
