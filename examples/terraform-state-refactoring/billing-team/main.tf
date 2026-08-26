# The billing team's root - a SEPARATE state file. After step 6 released the
# parameter (removed + destroy=false), this root adopts it declaratively: the
# import block is the read side of the handover. Plan previews the import,
# apply performs it. Once applied, the import block can be deleted - it is a
# one-shot migration instruction, not configuration.

import {
  to = aws_ssm_parameter.billing_export
  id = "/tf-state-refactoring/billing/export-bucket" # SSM import id = parameter name
}

resource "aws_ssm_parameter" "billing_export" {
  name  = "/${var.name_prefix}/billing/export-bucket"
  type  = "String"
  value = "s3://example-billing-exports"
}
