# Step 5b - the chained upgrade: jump to v3. Works from v2 (one hop) AND
# straight from v1 (two hops): v3's moved.tf chains config -> app_config -> this,
# Terraform replays the whole lineage in a single plan. This chain is the reason
# a published module keeps its moved blocks: drop one hop, break old consumers.
#
# Prove it (from a step-4 state, skipping step 5 entirely):
#   terraform init && terraform plan
#   -> ".config has moved to .this" resolved through the chain,
#      Plan: 0 to add, 0 to change, 0 to destroy.

module "app_config" {
  source = "../modules/app-config/v3"

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
