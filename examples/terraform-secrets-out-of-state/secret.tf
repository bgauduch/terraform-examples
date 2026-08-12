# ===========================================================================
# THE ONLY FILE THAT MOVES.
#
# This root module is a PROGRESSIVE LAB, and it starts on the anti-pattern.
# Do not copy this file as a reference - copy `final/` instead, which holds the
# target state alone.
#
# Six steps. Exactly one is active at a time: uncomment the next, comment the
# previous, and run the proof command from the README. Steps 3 and 5 fail on
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
  description = "Throwaway refresh token - the field a rotation changes. Never a real secret."
  type        = string
  default     = "dummy-refresh-token-v1"
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    client_id     = var.twitch_client_id
    client_secret = var.twitch_client_secret
    refresh_token = var.api_token
  })
}

# ---------------------------------------------------------------------------
# STEP 2 - sensitive values. The reflex, and why it is not enough.
#
# Three gestures; the second carries the lesson.
#
# 2a. Add the output below, then apply: the token prints in clear. The plan has
#     been masking `secret_string` since step 1 - the provider protects its own
#     attribute, nothing else.
#
# output "token_preview" {
#   value = var.api_token
# }
#
# 2b. Add `sensitive = true` to the variable, then plan:
#     `Error: Output refers to sensitive values`. The flag spreads to everything
#     derived from it - in a reusable module, the whole public interface.
#
# 2c. Mark the output sensitive in turn: the plan passes, it prints
#     `(sensitive value)`, and the step-1 proof shows the state unmoved.
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
# `ephemeral` brings a secret in. It cannot write it. Read the error again: it
# names the exit itself - a write-only attribute. That is step 4.
#
# The step-2 output does not survive this marche either: a root output cannot
# return an ephemeral value (`Ephemeral output not allowed` - the `ephemeral`
# output flag is child-module only). Where `sensitive` spread a flag through the
# interface, `ephemeral` evicts the output. The escape hatch for mixed values,
# `ephemeralasnull()`, keeps the output legal and hands the state exactly null:
#
# output "token_preview" {
#   value     = ephemeralasnull(var.api_token)
#   sensitive = true
# }
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# STEP 4 - write-only argument. The landing strip, and the migration.
#
# The variable keeps `ephemeral = true`. `secret_string_wo` is the write-only
# attribute the step-3 error was asking for: the value is sent, never stored.
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
#   secret_id = aws_secretsmanager_secret.app.id
#   secret_string_wo = jsonencode({
#     client_id     = var.twitch_client_id
#     client_secret = var.twitch_client_secret
#     refresh_token = var.api_token
#   })
#   secret_string_wo_version = 1
# }
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# STEP 5 - ephemeral block. The read path, and its usage restriction.
# A classic `data "aws_secretsmanager_secret_version"` puts the value back in the
# state on a plain READ. The ephemeral block does not. It replaces the data
# source, never the resource: the write path stays step 4's write-only argument.
#
# ephemeral "aws_secretsmanager_secret_version" "current" {
#   secret_id = aws_secretsmanager_secret.app.id
# }
#
# Referencing it outside an ephemeral context stops the plan. Same error as the
# step-3 output, and that is the point: the mark follows the value, not its
# source. What the block reads is born ephemeral. It is also the only visible
# gesture this step has - the block succeeding leaves no trace by design.
#
#   Error: Ephemeral value not allowed
#
#   This output value is not declared as returning an ephemeral value, so it
#   cannot be set to a result derived from an ephemeral value.
#
# The reflex - add `ephemeral = true` to the output - earns a second refusal:
#
#   Error: Ephemeral output not allowed
#
#   Ephemeral outputs are not allowed in context of a root module
#
# The flag is for child modules: it lets a value transit between modules DURING
# a run. A root output is where the run ends - it exists to be persisted. The
# root interface IS state, so what must not land cannot enter it.
#
# output "current_token" {
#   value = ephemeral.aws_secretsmanager_secret_version.current.secret_string
#   ephemeral = true
# }
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# STEP 6 - generated in place. A secret nobody has ever seen.
# Terraform generates it, hands it to the vault through the write-only argument,
# and keeps nothing. Consumers read it by ARN. No human is ever in the loop.
#
# Three gestures, in this order:
#
# 6a. Swap the write path: comment out the ACTIVE resource at the top of this
#     file, and uncomment BOTH blocks below together. They are one unit - the
#     ephemeral password (same block syntax as step 5, pointed at a generator
#     instead of the vault) is unusable without a write-only argument to land
#     in, and `secret_string_wo` has to be fed by something. Keep version = 1.
#
# 6b. Plan: `No changes`. The value moved (generated replaces the variable),
#     nothing ships - Terraform has no previous value to compare against. The
#     silent no-op, played rather than told.
#
# 6c. Bump the version to 2, plan, apply. The plan reads:
#       ~ secret_string_wo_version = 1 -> 2 # forces replacement
#     One integer, and the resource is replaced - correct, since a secret
#     version is immutable. AWSCURRENT moves to the new version, the old one
#     becomes AWSPREVIOUS. Rerun `fingerprint_command`: the fingerprint changed,
#     and the value never appeared anywhere.
#
# ephemeral "random_password" "app" {
#   length  = 32
#   special = true
# }

# resource "aws_secretsmanager_secret_version" "app" {
#   secret_id = aws_secretsmanager_secret.app.id
#   secret_string_wo = jsonencode({
#     client_id     = var.twitch_client_id
#     client_secret = var.twitch_client_secret
#     refresh_token = ephemeral.random_password.app.result
#   })
#   secret_string_wo_version = 1
# }
# ---------------------------------------------------------------------------
