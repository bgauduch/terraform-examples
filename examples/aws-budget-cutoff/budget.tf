# The native cut-off: a tiny cost budget on the sandbox account + a Budget Action that
# attaches the surgical SCP when the threshold is crossed. This is the whole critical path -
# no Lambda, no SNS, no EventBridge in it. Two API calls, one role, one prepared SCP.

data "aws_iam_policy_document" "budgets_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }
  }
}

# Role AWS Budgets assumes to attach/detach the SCP via Organizations.
resource "aws_iam_role" "budgets_exec" {
  name               = "budgets-cutoff-exec"
  assume_role_policy = data.aws_iam_policy_document.budgets_assume.json
}

data "aws_iam_policy_document" "budgets_exec" {
  statement {
    sid    = "AttachDetachCutoffScp"
    effect = "Allow"
    actions = [
      "organizations:AttachPolicy",
      "organizations:DetachPolicy",
      "organizations:ListPolicies",
      "organizations:ListPoliciesForTarget",
      "organizations:ListTargetsForPolicy",
      "organizations:DescribePolicy",
      "organizations:ListRoots",
      "organizations:ListAccounts",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "budgets_exec" {
  name   = "budgets-cutoff-exec"
  role   = aws_iam_role.budgets_exec.id
  policy = data.aws_iam_policy_document.budgets_exec.json
}

# Tiny monthly cost budget scoped to the sandbox linked account. The email notification is
# the human "heads-up"; the SCP attach below is the actual guardrail. The remediation loop
# (SNS + Lambda) is a separate, off-critical-path layer.
resource "aws_budgets_budget" "cutoff" {
  name         = "sandbox-cutoff-demo"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = [var.sandbox_account_id]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notify_email]
  }
}

# The cut-off itself. MANUAL approval so the demo can approve it on stage (execute-budget-action
# APPROVE_BUDGET_ACTION) instead of waiting for the ~8-12h evaluation cycle.
resource "aws_budgets_budget_action" "cutoff" {
  budget_name        = aws_budgets_budget.cutoff.name
  action_type        = "APPLY_SCP_POLICY"
  approval_model     = "MANUAL"
  notification_type  = "ACTUAL"
  execution_role_arn = aws_iam_role.budgets_exec.arn

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 100
  }

  definition {
    scp_action_definition {
      policy_id  = aws_organizations_policy.cutoff_surgical.id
      target_ids = [var.sandbox_account_id]
    }
  }

  subscriber {
    address           = var.notify_email
    subscription_type = "EMAIL"
  }
}
