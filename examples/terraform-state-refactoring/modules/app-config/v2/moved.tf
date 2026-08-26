# Shipped WITH the release that renames the resource. Consumers upgrading
# v1 -> v2 replay this move in their own state at the next plan/apply: the
# migration travels with the module, nobody runs `terraform state mv` by hand.
# Producer rule: this block is part of the module's API. Removing it would break
# every consumer still on v1 - it stays for the lifetime of the major.

moved {
  from = aws_ssm_parameter.config
  to   = aws_ssm_parameter.app_config
}
