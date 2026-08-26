# app-config v3 - second internal refactor: `app_config` renamed to `this`
# (single-resource module canonical naming). moved.tf now carries the CHAIN of
# moves: a consumer jumping v1 -> v3 replays both in one plan. See MIGRATION.md.

resource "aws_ssm_parameter" "this" {
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
