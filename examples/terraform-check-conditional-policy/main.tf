# Cross-cutting locals and data sources. Per-service files: iam.tf, kms.tf,
# s3.tf; the check blocks live on their own in checks.tf.

locals {
  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }

  account_root    = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  permanent_admin = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.permanent_admin_role_name}"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_organizations_organization" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}
