variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "kms_key_arn" {
  description = <<-EOT
    ARN of the KMS key to inject into the consuming module. The whole point of this
    experiment: this ARN may be dynamic and unknown at plan time (e.g. the key is
    created in the same apply). Deferred actions (`terraform plan -allow-deferral`)
    let the plan tolerate that unknown value instead of erroring.
  EOT
  type        = string
  default     = null
}
