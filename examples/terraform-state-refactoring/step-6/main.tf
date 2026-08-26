# Step 6 - handover to another team, i.e. to another STATE FILE.
#
# `moved` cannot cross state files: it edits one state, it never bridges two.
# The workflow that takes over is a pair of blocks, one on each side:
#   - here    `removed` + destroy=false -> this state forgets the parameter,
#             AWS keeps it. Nothing is destroyed.
#   - there   `import` in ../billing-team/ -> that state adopts it.
# The resource never stops existing; only its owner changes.
#
# Play it:
#   terraform plan    -> "will no longer be managed by Terraform, but will not
#                         be destroyed" - Plan: 0 to add, 0 to change, 0 to destroy.
#   terraform apply   -> gone from THIS state, still live on AWS (check with
#                        `aws ssm get-parameter --name /<prefix>/billing/export-bucket`).
#   cd ../billing-team && terraform init && terraform apply
#                     -> "Plan: 1 to import" then "1 imported". New owner.
#
# Rewinding after this step: see the README, "Rewind and teardown". This root no
# longer manages the parameter, so replaying step 1 would try to CREATE it and
# hit ParameterAlreadyExists.

module "app_config" {
  source = "../modules/app-config/v3"

  name_prefix = var.name_prefix
  config = {
    log_level = "info"
    timeout_s = "30"
  }
  feature_flags = var.feature_flags
}

removed {
  from = aws_ssm_parameter.billing_export

  lifecycle {
    destroy = false
  }
}
