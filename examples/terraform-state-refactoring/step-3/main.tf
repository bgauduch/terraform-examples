# Step 3 - demo 2: migrate the config parameter to the platform team's module
# to get back into compliance. The module manages the same parameter, same name:
# adoption is a pure state move, written by the CONSUMER (this root).
#
# Note: the step-2 moved block is gone. Root rule: a root module keeps a moved
# block only until it is applied in every environment, then cleans it up. A
# PUBLISHED module keeps its moved blocks forever (see ../modules/app-config).
#
# Prove it:
#   terraform init   (new module source)
#   terraform plan   -> "aws_ssm_parameter.app_config has moved to
#                        module.app_config.aws_ssm_parameter.config"
#                       Plan: 0 to add, 0 to change, 0 to destroy.

module "app_config" {
  source = "../modules/app-config/v1"

  name_prefix = var.name_prefix
  config = {
    log_level = "info"
    timeout_s = "30"
  }
}

moved {
  from = aws_ssm_parameter.app_config
  to   = module.app_config.aws_ssm_parameter.config
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
