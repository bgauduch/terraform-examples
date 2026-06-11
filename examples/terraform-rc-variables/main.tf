# Scaffold only - the deferred-actions wiring is added live.
#
# Goal: pass `var.kms_key_arn` (potentially unknown at plan) into a module and let
# Terraform defer the affected resources instead of failing the plan. Run with:
#
#   terraform plan -allow-deferral -var 'kms_key_arn=<arn-or-unknown>'
#
# Until the RC step is wired, this file only surfaces the input so the example
# validates and is picked up by CI auto-discovery.

locals {
  kms_key_arn = var.kms_key_arn
}
