variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "project" {
  description = "Project name used for tagging"
  type        = string
}
