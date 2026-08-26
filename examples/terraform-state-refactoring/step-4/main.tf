# Step 4 - the split reaches the for_each set: the feature flags move into the
# module. One moved block on the RESOURCE address carries every instance
# ("dark-mode", "beta-api", ...) - no per-key block needed for a 1:1 move.
#
# Prove it:
#   terraform plan   -> one "has moved to" line per flag instance,
#                       Plan: 0 to add, 0 to change, 0 to destroy.

module "app_config" {
  source = "../modules/app-config/v1"

  name_prefix = var.name_prefix
  config = {
    log_level = "info"
    timeout_s = "30"
  }
  feature_flags = var.feature_flags
}

moved {
  from = aws_ssm_parameter.feature_flags
  to   = module.app_config.aws_ssm_parameter.feature_flags
}

resource "aws_ssm_parameter" "billing_export" {
  name  = "/${var.name_prefix}/billing/export-bucket"
  type  = "String"
  value = "s3://example-billing-exports"
}
