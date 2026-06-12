variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "bucket_prefix" {
  description = "Prefix for the demo bucket names (a random suffix is appended for global uniqueness)."
  type        = string
  default     = "tf-deferred-demo"
}
