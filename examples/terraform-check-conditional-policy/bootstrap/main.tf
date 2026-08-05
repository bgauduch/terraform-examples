# ---------------------------------------------------------------------------
# The platform baseline, as a separate root module on purpose.
#
# In the real setup these roles come from another stack, owned by another team,
# rolled out account by account. Here, applying this module means "this account
# received the baseline" and destroying it means "this one did not yet" - which
# is what the parent lab's check blocks observe.
# ---------------------------------------------------------------------------

locals {
  common_tags = {
    Project   = "demo-tf-check-policy"
    ManagedBy = "terraform"
    Baseline  = "platform"
  }
}

data "aws_caller_identity" "current" {}

# Trust the account itself: enough to make the roles real and assumable, with no
# standing access granted to anyone outside.
data "aws_iam_policy_document" "assume_from_account" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "platform_admin" {
  name               = var.platform_admin_role_name
  description        = "Platform administration role - part of the account baseline"
  assume_role_policy = data.aws_iam_policy_document.assume_from_account.json
  tags               = local.common_tags
}

resource "aws_iam_role" "break_glass" {
  name               = var.break_glass_role_name
  description        = "Emergency access role - part of the account baseline"
  assume_role_policy = data.aws_iam_policy_document.assume_from_account.json
  tags               = local.common_tags
}
