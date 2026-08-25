# Step 6 - handover: the billing parameter never belonged here. `moved` cannot
# cross state files - the workflow that takes over is `removed` (forget without
# destroying) here, then an `import` block in the billing team's root
# (../adjacent). The resource survives the whole trip.
#
# Prove it:
#   terraform plan   -> "will no longer be managed by Terraform, but will not be
#                        destroyed" - Plan: 0 to add, 0 to change, 0 to destroy.
#   terraform apply  -> parameter gone from THIS state, still on AWS.
#   then: cd ../adjacent && terraform init && terraform plan -> "to import"

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
