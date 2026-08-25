variable "name_prefix" {
  description = "SSM parameter name prefix, without leading slash."
  type        = string
}

variable "config" {
  description = "Application configuration, stored as one JSON SSM parameter."
  type        = map(string)
}

variable "feature_flags" {
  description = "Feature flags, one SSM parameter per flag."
  type        = map(string)
  default     = {}
}
