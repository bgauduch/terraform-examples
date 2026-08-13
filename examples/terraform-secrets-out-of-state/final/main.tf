# ---------------------------------------------------------------------------
# The target state, on its own. This is the file to copy.
#
# Terraform generates the secret, hands it to the vault through a write-only
# argument, and keeps nothing: not in the state, not in the plan, not in the
# logs. Consumers read it by ARN at runtime, so no human is ever in the loop.
#
# The walkthrough that gets here one defect at a time lives in the parent module.
# ---------------------------------------------------------------------------

locals {
  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

resource "aws_kms_key" "secrets" {
  description             = "Encrypts the ${var.project} secret."
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = local.common_tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project}"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "app" {
  name        = "${var.project}/api-token"
  description = "Generated in place, never stored by Terraform."
  kms_key_id  = aws_kms_key.secrets.arn

  # A production secret keeps the default 7-day recovery window. Zero here so the
  # example can be destroyed and re-applied back to back.
  recovery_window_in_days = 0

  tags = local.common_tags
}

# An ephemeral resource is opened on every plan AND every apply, and its result
# is never persisted. It is one of the few places a secret can legitimately come
# from, the other being an ephemeral input variable.
ephemeral "random_password" "app" {
  length  = 32
  special = true
}

# secret_string_wo is a write-only argument: the provider receives the value at
# apply time and Terraform discards it. Only secret_string_wo_version reaches the
# state, which is why rotation is a version bump rather than a value diff.
#
# Bumping the version REPLACES this resource. That is correct: a secret version
# is immutable, so rotating means creating a new one.
resource "aws_secretsmanager_secret_version" "app" {
  secret_id                = aws_secretsmanager_secret.app.id
  secret_string_wo         = ephemeral.random_password.app.result
  secret_string_wo_version = var.secret_version
}
