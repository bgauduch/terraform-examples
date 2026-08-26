# app-config v1 - the platform team's module.
# Parameter names match what a compliant app root would use: adopting the module
# is then a pure state move (`moved` on the consumer side), zero infrastructure diff.

resource "aws_ssm_parameter" "config" {
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
