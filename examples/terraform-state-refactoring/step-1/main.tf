# Step 1 - the starting point: a flat root module, grown organically.
# Naming drifted (`cfg_param_1`), feature flags sit at the root, and a parameter
# owned by the billing team slipped in. Every later step refactors this file
# WITHOUT touching the infrastructure: the target output of each step is a plan
# that says "no changes" (or moves only).
#
# This directory is the live playground: `../scripts/switch.sh <step>` overlays
# the .tf files of a step snapshot here while the state stays put.

resource "aws_ssm_parameter" "cfg_param_1" {
  name  = "/${var.name_prefix}/app/config"
  type  = "String"
  value = jsonencode({ log_level = "info", timeout_s = "30" })
}

resource "aws_ssm_parameter" "feature_flags" {
  for_each = var.feature_flags

  name  = "/${var.name_prefix}/app/flags/${each.key}"
  type  = "String"
  value = each.value
}

# Owned by the billing team, landed in this root by mistake. Step 6 hands it
# back without destroying it: `removed` + destroy=false here, `import` block in
# ../billing-team/ - the team's own root module, with its own state file.
resource "aws_ssm_parameter" "billing_export" {
  name  = "/${var.name_prefix}/billing/export-bucket"
  type  = "String"
  value = "s3://example-billing-exports"
}
