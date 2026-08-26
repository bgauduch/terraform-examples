variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "SSM parameter name prefix, without leading slash. Must match the value used in ../live."
  type        = string
  default     = "tf-state-refactoring"
}
