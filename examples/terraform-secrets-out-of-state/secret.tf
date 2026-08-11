# ===========================================================================
# THE ONLY FILE THAT MOVES.
#
# This root module is a PROGRESSIVE LAB, and it starts on the anti-pattern.
# Do not copy this file as a reference - copy `final/` instead, which holds the
# target state alone.
#
# Six steps. Exactly one is active at a time: uncomment the next, comment the
# previous, and run the proof command from the README. Steps 3 and 4 fail on
# purpose - that is what they teach, so they can never be the active step in CI.
#
# Every value in this lab is throwaway.
# ===========================================================================

# ---------------------------------------------------------------------------
# STEP 1 - the plain variable. Where most configurations still are.
#
# Read the plan first: `secret_string` already shows as `(sensitive value)`,
# because the AWS provider marks that attribute Sensitive in its own schema.
# Nothing has been configured, and the plan already looks safe. That is the trap.
#
# Proof: see `state_proof_command` in outputs.tf. The token is there, in clear.
# ---------------------------------------------------------------------------
variable "api_token" {
  description = "Throwaway credential set, JSON encoded. Never a real secret."
  type        = string
  default     = "{\"client_id\":\"dummy-client-id\",\"client_secret\":\"dummy-client-secret\",\"refresh_token\":\"dummy-refresh-token-v1\"}"
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id     = aws_secretsmanager_secret.app.id
  secret_string = var.api_token
}

# ---------------------------------------------------------------------------
# STEP 2 - sensitive values. The reflex, and why it is not enough.
# Add `sensitive = true` to the variable above, then re-run the same proof.
# The state has not moved one byte.
#
# What `sensitive` actually buys is not the plan (the provider already masked
# that attribute) but everywhere else the value travels: outputs, locals, other
# resources, error messages.
#
# The contagion, worth seeing once: a derived output stops the plan with
# "Output refers to sensitive values" until it is marked sensitive too. In a
# reusable module that spreads across the whole public interface.
#
# output "token_preview" {
#   value = var.api_token
# }
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# STEP 3 - ephemeral argument. The wall, and the clearest error in Terraform.
# Add `ephemeral = true` to the variable, keep `secret_string` above, then plan:
#
#   Error: Invalid use of ephemeral value
#
#   Ephemeral values are not valid for "secret_string", because it is not a
#   write-only attribute and must be persisted to state.
#
# The value can no longer reach the state, and it has nowhere to land either.
# `ephemeral` brings a secret in. It cannot write it.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# STEP 4 - ephemeral block. The other source, and its usage restriction.
# A classic `data "aws_secretsmanager_secret_version"` puts the value back in the
# state on a plain READ. The ephemeral block does not.
#
# ephemeral "aws_secretsmanager_secret_version" "current" {
#   secret_id = aws_secretsmanager_secret.app.id
# }
#
# Referencing it outside an ephemeral context stops the plan:
#
#   Error: Ephemeral value not allowed
#
#   This output value is not declared as returning an ephemeral value, so it
#   cannot be set to a result derived from an ephemeral value.
#
# output "current_token" {
#   value = ephemeral.aws_secretsmanager_secret_version.current.secret_string
# }
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# STEP 5 - write-only argument. The landing strip, and the migration.
#
# Switching an EXISTING resource from `secret_string` to `secret_string_wo` is
# an in-place update. The plan shows `secret_string -> null` plus the new version
# argument, and `secret_string_wo` never appears - write-only values are absent
# from plans by design. The value is still transmitted (verified on this
# resource, see README "Migrating an existing secret").
#
# After apply the state holds has_secret_string_wo = true and an EMPTY
# secret_string. The current state is clean; earlier state versions are not.
#
# resource "aws_secretsmanager_secret_version" "app" {
#   secret_id                = aws_secretsmanager_secret.app.id
#   secret_string_wo         = var.api_token
#   secret_string_wo_version = 1
# }
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# STEP 6 - generated in place. A secret nobody has ever seen.
# Terraform generates it, hands it to the vault through the write-only argument,
# and keeps nothing. Consumers read it by ARN. No human is ever in the loop.
#
# Rotation is the version bump. The plan reads:
#   ~ secret_string_wo_version = 1 -> 2 # forces replacement
# One integer, and the resource is replaced - correct, since a secret version is
# immutable. AWSCURRENT moves to the new version, the old one becomes AWSPREVIOUS.
#
# ephemeral "random_password" "app" {
#   length  = 32
#   special = true
# }
#
# resource "aws_secretsmanager_secret_version" "app" {
#   secret_id = aws_secretsmanager_secret.app.id
#   secret_string_wo = jsonencode({
#     client_id     = "dummy-client-id"
#     client_secret = "dummy-client-secret"
#     refresh_token = ephemeral.random_password.app.result
#   })
#   secret_string_wo_version = 1
# }
# ---------------------------------------------------------------------------
