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

variable "sink" {
  description = <<-EOT
    Where the consumer reports the fingerprint. `stdout` returns it in the invoke
    response and needs nothing else. `twitch` also posts it to a chat, which requires
    the secret to hold a full credential set and `twitch_user_id` to be set.
    The demo proves the same thing either way.
  EOT
  type        = string
  default     = "stdout"

  validation {
    condition     = contains(["stdout", "twitch"], var.sink)
    error_message = "sink must be either \"stdout\" or \"twitch\"."
  }
}

variable "twitch_user_id" {
  description = "Twitch numeric user id, used as both broadcaster and sender. Only read when sink = twitch."
  type        = string
  default     = ""
}

# The two halves of the credential set that never rotate. Dummy by default so the
# walkthrough stays inert; inject real values (TF_VAR_*) only from step 4 on -
# at steps 1-3 the secret is persisted in state, and these land inside it.
variable "twitch_client_id" {
  description = "Twitch app client id, stored in the credential set. Real value only needed when sink = twitch."
  type        = string
  default     = "dummy-client-id"
}

variable "twitch_client_secret" {
  description = "Twitch app client secret, stored in the credential set. Real value only needed when sink = twitch."
  type        = string
  default     = "dummy-client-secret"
  sensitive   = true
}
