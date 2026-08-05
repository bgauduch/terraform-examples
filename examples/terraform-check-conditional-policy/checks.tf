# ---------------------------------------------------------------------------
# The signal, as opposed to the gate in kms.tf.
#
# The check carries its own scoped data source: re-read on every plan and apply,
# and reachable from nowhere else in the configuration. A failure surfaces as a
# WARNING and the run keeps its exit code 0 - an account mid-migration is worth
# knowing about, and blocking every deployment over it would be the wrong trade.
#
# A check earns its place when the fact it observes is one Terraform does NOT
# manage. Asserting on a managed attribute instead gets you nothing: the drift
# already shows up as a resource diff, and the pending change makes Terraform
# defer the check to apply time ("known after apply") - by which point the apply
# has reconciled the very thing the check was watching for.
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
