# Copy to ../terraform.tfvars (gitignored) and fill with your real values.
# Account ids are not secrets, but keep your real ones out of this committed example file.

mgmt_profile    = "my-management-sso-profile"
sandbox_profile = "my-sandbox-sso-profile"

mgmt_account_id    = "111111111111"
sandbox_account_id = "222222222222"

notify_email = "you@example.com"

# Optional overrides:
# region                = "eu-west-1"
# break_glass_role_name = "break-glass-admin"
# budget_limit_usd      = "0.01"
# runaway_instance_type = "t3.micro"
