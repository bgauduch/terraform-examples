variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "SSM parameter name prefix, without leading slash."
  type        = string
  default     = "tf-state-refactoring"
}

variable "feature_flags" {
  description = "Feature flags, one SSM parameter per flag."
  type        = map(string)
  default = {
    dark-mode = "off"
    beta-api  = "on"
  }
}
