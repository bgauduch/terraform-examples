# Step 5 - producer side: bump the module v1 -> v2. The new version renames a
# resource INTERNALLY and ships the move itself (moved.tf + MIGRATION.md in
# ../modules/app-config/v2). The consumer changes one line: the source.
#
# Prove it:
#   terraform init   (module source changed)
#   terraform plan   -> "module.app_config.aws_ssm_parameter.config has moved to
#                        module.app_config.aws_ssm_parameter.app_config"
#                       Plan: 0 to add, 0 to change, 0 to destroy.
# No moved block in THIS file: the migration ships with the module.

module "app_config" {
  source = "../modules/app-config/v2"

  name_prefix = var.name_prefix
  config = {
    log_level = "info"
    timeout_s = "30"
  }
  feature_flags = var.feature_flags
}

resource "aws_ssm_parameter" "billing_export" {
  name  = "/${var.name_prefix}/billing/export-bucket"
  type  = "String"
  value = "s3://example-billing-exports"
}
