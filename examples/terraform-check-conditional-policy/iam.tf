# Who this account turns out to have, and the application identity that consumes
# the key. The verdicts drawn from these lookups live in kms.tf and checks.tf.

locals {
  # Empty in accounts where the baseline has yet to land. That state is legitimate
  # for one of these roles and disqualifying for the other - see kms.tf.
  platform_admin_arns = tolist(data.aws_iam_roles.platform_admin.arns)
  break_glass_arns    = tolist(data.aws_iam_roles.break_glass.arns)

  key_admin_principals = concat(
    ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.permanent_admin_role_name}"],
    local.platform_admin_arns,
    local.break_glass_arns,
  )
}

# ---------------------------------------------------------------------------
# These lookups FEED the key policy, so they live at top level. The plural data
# source returns an empty set when nothing matches, where the singular
# `aws_iam_role` raises an error and fails the plan - that difference is what
# lets one module deploy across accounts at different baseline stages.
#
# checks.tf re-reads the same roles through its own scoped data sources. That is
# deliberate: a check observes reality rather than trusting what the
# configuration computed, and a scoped data source is invisible to everything
# outside its own check.
# ---------------------------------------------------------------------------
data "aws_iam_roles" "platform_admin" {
  name_regex = "^${var.platform_admin_role_name}$"
}

data "aws_iam_roles" "break_glass" {
  name_regex = "^${var.break_glass_role_name}$"
}

# ---------------------------------------------------------------------------
# The application identity. It holds no KMS permission of its own: everything it
# can do with the key comes from the key policy in kms.tf.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "app_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.project}-app"
  description        = "Application role granted encrypted access to the demo bucket"
  assume_role_policy = data.aws_iam_policy_document.app_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "app_bucket_access" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.data.arn}/*"]
  }
}

resource "aws_iam_role_policy" "app_bucket_access" {
  name   = "bucket-access"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_bucket_access.json
}
