# ---------------------------------------------------------------------------
# Signals, as opposed to the gate in kms.tf.
#
# Each check carries its own scoped data source: re-read on every plan and
# apply, and reachable from nowhere else in the configuration. Failures surface
# as WARNINGS and the run keeps its exit code 0 - an account mid-migration, or a
# key an operator disabled by hand, are things to know about, and blocking every
# deployment over them would be the wrong trade.
# ---------------------------------------------------------------------------

# The platform admin role legitimately lags behind in accounts the baseline has
# yet to reach. The key policy renders without it, and this says so out loud.
check "platform_admin_role_present" {
  data "aws_iam_roles" "platform_admin_observed" {
    name_regex = "^${var.platform_admin_role_name}$"
  }

  assert {
    condition     = length(data.aws_iam_roles.platform_admin_observed.arns) > 0
    error_message = "Platform administration role '${var.platform_admin_role_name}' is absent from this account, so the key policy grants administration without it. Expected once the platform baseline reaches this account."
  }
}

# Health of the deployed key itself, re-read from AWS rather than from state, so
# a key disabled or scheduled for deletion out of band shows up on the next plan.
check "key_operational" {
  data "aws_kms_key" "deployed" {
    key_id = aws_kms_key.app.key_id
  }

  assert {
    condition     = data.aws_kms_key.deployed.key_state == "Enabled"
    error_message = "Key ${aws_kms_key.app.key_id} reports state '${data.aws_kms_key.deployed.key_state}': any state other than Enabled leaves the bucket unable to encrypt or read its objects."
  }
}
