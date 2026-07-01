output "budget_name" {
  description = "Cost budget carrying the cut-off action."
  value       = aws_budgets_budget.cutoff.name
}

output "budget_action_id" {
  description = "Budget Action id - use it to approve the pending action on stage."
  value       = aws_budgets_budget_action.cutoff.action_id
}

output "cutoff_surgical_policy_id" {
  description = "SCP the action attaches to the sandbox account (hybrid blast)."
  value       = aws_organizations_policy.cutoff_surgical.id
}

output "cutoff_hard_policy_id" {
  description = "Contrast SCP (deny-all-but-break-glass), never wired to the action."
  value       = aws_organizations_policy.cutoff_hard.id
}

output "runaway_instance_id" {
  description = "The demo runaway EC2 instance."
  value       = aws_instance.runaway.id
}

output "remediation_lambda" {
  description = "Remediation Lambda - invoke it to auto-terminate the runaway and notify."
  value       = aws_lambda_function.remediation.function_name
}

output "notify_topic_arn" {
  description = "SNS topic that emails the remediation confirmation."
  value       = aws_sns_topic.notify.arn
}

output "approve_action_cli" {
  description = "One-liner to fire the cut-off on stage (once the action is PENDING)."
  value       = "aws budgets execute-budget-action --account-id ${var.mgmt_account_id} --budget-name ${aws_budgets_budget.cutoff.name} --action-id ${aws_budgets_budget_action.cutoff.action_id} --execution-type APPROVE_BUDGET_ACTION --profile ${var.mgmt_profile}"
}

output "manual_attach_cli" {
  description = "Fallback: attach the surgical SCP directly (the exact payload the action runs)."
  value       = "aws organizations attach-policy --policy-id ${aws_organizations_policy.cutoff_surgical.id} --target-id ${var.sandbox_account_id} --profile ${var.mgmt_profile}"
}
