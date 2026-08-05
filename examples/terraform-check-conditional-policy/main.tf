locals {
  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }

  account_root = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"

  # Empty in accounts where the platform role was never rolled out.
  ops_role_arns = tolist(data.aws_iam_roles.ops.arns)

  # The whole point: the admin list degrades gracefully instead of failing.
  key_admin_principals = concat([local.account_root], local.ops_role_arns)
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# The PLURAL data source returns an EMPTY set when nothing matches, where the
# singular `aws_iam_role` raises an error and fails the plan. That difference is
# what makes an optional, environment-dependent lookup possible at all.
#
# It lives at top level (not scoped inside the check) because the key policy
# consumes it: a check-scoped data source is only visible inside its own check.
# ---------------------------------------------------------------------------
data "aws_iam_roles" "ops" {
  name_regex = "^${var.ops_role_name}$"
}

data "aws_iam_policy_document" "key" {
  # Wildcard actions on the key itself are the documented KMS pattern: a key
  # policy is scoped to its own key, and the account root delegation is what
  # lets IAM policies grant access at all.
  statement {
    sid       = "KeyAdministration"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = local.key_admin_principals
    }
  }
}

resource "aws_kms_key" "app" {
  description             = "Demo key whose administrators depend on what exists in this account"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key.json
  tags                    = local.common_tags
}

resource "aws_kms_alias" "app" {
  name          = "alias/${var.project}"
  target_key_id = aws_kms_key.app.key_id
}

# ---------------------------------------------------------------------------
# The assumption made explicit. The config already handled the role's absence
# silently; the check is what turns that silence into a signal - as a WARNING,
# so the environments where the role legitimately does not exist still deploy.
# A precondition here would block them instead.
# ---------------------------------------------------------------------------
check "ops_role_present" {
  assert {
    condition     = length(local.ops_role_arns) > 0
    error_message = "Role '${var.ops_role_name}' is absent from this account: the KMS key policy was rendered without it. Expected wherever the platform baseline is rolled out."
  }
}
