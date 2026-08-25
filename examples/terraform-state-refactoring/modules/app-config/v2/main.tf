# app-config v2 - internal refactor: `config` renamed to `app_config` to match
# the team naming convention. No consumer-facing change: same variables, same
# parameter names. The rename ships with its own moved.tf - see MIGRATION.md.

resource "aws_ssm_parameter" "app_config" {
  name  = "/${var.name_prefix}/app/config"
  type  = "String"
  value = jsonencode(var.config)
}

resource "aws_ssm_parameter" "feature_flags" {
  for_each = var.feature_flags

  name  = "/${var.name_prefix}/app/flags/${each.key}"
  type  = "String"
  value = each.value
}
