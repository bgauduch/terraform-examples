# Two Service Control Policies, created UNATTACHED in the management account.
# The Budget Action attaches `cutoff_surgical` to the sandbox account when approved.
# `cutoff_hard` exists only to contrast blast radius on screen - it is never wired to the action.

locals {
  break_glass_arn = "arn:aws:iam::${var.sandbox_account_id}:role/${var.break_glass_role_name}"

  # Actions that make the bill climb. Denying these freezes new spend while leaving
  # read/describe and terminate/delete intact -> the "hybrid blast".
  cost_driver_actions = [
    "ec2:RunInstances",
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "sagemaker:CreateEndpoint",
    "sagemaker:CreateTrainingJob",
    "sagemaker:CreateNotebookInstance",
    "rds:CreateDBInstance",
    "rds:CreateDBCluster",
  ]
}

# Surgical (hybrid) cut-off: freeze the cost drivers, spare everything else.
# describe/list stays up (you can still see), terminate/delete stays up (you can still clean),
# the break-glass role is exempt from the whole deny (anti-lock-out).
resource "aws_organizations_policy" "cutoff_surgical" {
  name        = "cutoff-surgical"
  description = "Hybrid cut-off: deny cost drivers, keep read + cleanup + break-glass alive."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "FreezeCostDrivers"
      Effect   = "Deny"
      Action   = local.cost_driver_actions
      Resource = "*"
      Condition = {
        ArnNotLike = {
          "aws:PrincipalArn" = local.break_glass_arn
        }
      }
    }]
  })
}

# Hard cut-off: deny everything except the break-glass role. Shown as the "too radical"
# counter-example - a full freeze also blinds and handcuffs you.
resource "aws_organizations_policy" "cutoff_hard" {
  name        = "cutoff-hard"
  description = "Full cut-off: deny all except break-glass. Contrast example, not wired to the action."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyAllButBreakGlass"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        ArnNotLike = {
          "aws:PrincipalArn" = local.break_glass_arn
        }
      }
    }]
  })
}
