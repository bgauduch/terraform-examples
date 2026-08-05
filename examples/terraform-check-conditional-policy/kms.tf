locals {
  # The administration surface, spelled out. `kms:*` would also hand out Decrypt
  # and GenerateDataKey, which administrators have no business holding.
  key_admin_actions = [
    "kms:CancelKeyDeletion",
    "kms:Create*",
    "kms:Delete*",
    "kms:Describe*",
    "kms:Disable*",
    "kms:Enable*",
    "kms:Get*",
    "kms:List*",
    "kms:Put*",
    "kms:Revoke*",
    "kms:RotateKeyOnDemand",
    "kms:ScheduleKeyDeletion",
    "kms:TagResource",
    "kms:UntagResource",
    "kms:Update*",
  ]

  key_usage_actions = [
    "kms:Decrypt",
    "kms:DescribeKey",
    "kms:Encrypt",
    "kms:GenerateDataKey*",
    "kms:ReEncrypt*",
  ]
}

# ---------------------------------------------------------------------------
# Key policy. Five statements, following the AWS key-policy baseline.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "key" {
  # 1. The delegation AWS documents: it lets IAM policies in this account govern
  #    the key, and it is the safety net that keeps the key administrable.
  statement {
    sid       = "EnableIAMUserPermissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
  }

  # 2. Administration, restricted to named principals. One is permanent, the two
  #    baseline roles join according to what this account turns out to have.
  statement {
    sid       = "KeyAdministration"
    actions   = local.key_admin_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = local.key_admin_principals
    }
  }

  # 3. Usage, and only through S3. A leaked credential cannot call Decrypt
  #    directly - the request has to arrive via the service.
  statement {
    sid       = "KeyUsageByApplicationViaS3"
    actions   = local.key_usage_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.app.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.region}.amazonaws.com"]
    }
  }

  # 4. Grants, restricted to those an AWS service creates on the caller's behalf
  #    (S3 needs one to encrypt objects with this key).
  statement {
    sid       = "AllowGrantsForAWSServices"
    actions   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.app.arn]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # 5. The perimeter: nothing outside the organization touches this key. The
  #    second condition spares AWS service principals, which carry no
  #    aws:PrincipalOrgID and would otherwise be denied along with everyone else.
  dynamic "statement" {
    for_each = var.enable_org_deny ? [1] : []

    content {
      sid       = "DenyOutsideOrganization"
      effect    = "Deny"
      actions   = ["kms:*"]
      resources = ["*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEquals"
        variable = "aws:PrincipalOrgID"
        values   = [data.aws_organizations_organization.current.id]
      }

      condition {
        test     = "BoolIfExists"
        variable = "aws:PrincipalIsAWSService"
        values   = ["false"]
      }
    }
  }
}

resource "aws_kms_key" "app" {
  description             = "Demo key whose administrators depend on what exists in this account"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key.json
  tags                    = local.common_tags

  # One of the two baseline roles, answered as a GATE. A key of this class calls
  # for a named, audited emergency path, so an account still waiting on one has
  # to receive it before it can hold the key.
  #
  # Two guarantees already stand behind it - the root delegation in statement 1
  # and the permanent admin in statement 2 - and the requirement holds anyway:
  # defence in depth is a policy choice, not a consequence of having no options.
  #
  # The other baseline role gets the opposite answer, as a SIGNAL: see checks.tf.
  lifecycle {
    precondition {
      condition     = length(local.break_glass_arns) > 0
      error_message = "Emergency access role '${var.break_glass_role_name}' is absent from this account. A key of this class requires a named, audited break-glass path: roll out the baseline before deploying it here."
    }
  }
}

resource "aws_kms_alias" "app" {
  name          = "alias/${var.project}"
  target_key_id = aws_kms_key.app.key_id
}
