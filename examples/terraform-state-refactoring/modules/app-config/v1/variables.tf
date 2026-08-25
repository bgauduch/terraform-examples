variable "name_prefix" {
  description = "SSM parameter name prefix, without leading slash."
  type        = string
}

variable "config" {
  description = "Application configuration, stored as one JSON SSM parameter."
  type        = map(string)
}

variable "feature_flags" {
  description = "Feature flags, one SSM parameter per flag. Empty by default so consumers can adopt the module for the config parameter first (step 3) and hand over the flags later (step 4)."
  type        = map(string)
  default     = {}
}
