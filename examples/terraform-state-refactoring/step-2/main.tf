# Step 2 - demo 1: rename to comply with the naming convention.
# `cfg_param_1` says nothing; the convention wants `app_config`. Without the
# moved block, plan answers destroy + create. With it: a pure state move.
#
# Prove it:
#   terraform plan   -> "aws_ssm_parameter.cfg_param_1 has moved to aws_ssm_parameter.app_config"
#                       Plan: 0 to add, 0 to change, 0 to destroy.
#   terraform apply  -> state updated, infrastructure untouched.

resource "aws_ssm_parameter" "app_config" {
  name  = "/${var.name_prefix}/app/config"
  type  = "String"
  value = jsonencode({ log_level = "info", timeout_s = "30" })
}

moved {
  from = aws_ssm_parameter.cfg_param_1
  to   = aws_ssm_parameter.app_config
}

resource "aws_ssm_parameter" "feature_flags" {
  for_each = var.feature_flags

  name  = "/${var.name_prefix}/app/flags/${each.key}"
  type  = "String"
  value = each.value
}

resource "aws_ssm_parameter" "billing_export" {
  name  = "/${var.name_prefix}/billing/export-bucket"
  type  = "String"
  value = "s3://example-billing-exports"
}
