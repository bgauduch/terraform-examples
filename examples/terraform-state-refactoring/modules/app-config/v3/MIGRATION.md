# app-config v2 -> v3 (and v1 -> v3)

## What changes

Internal rename: `aws_ssm_parameter.app_config` -> `aws_ssm_parameter.this`.
No variable, output, or parameter name changes.

## What you do

1. Bump the module source/version to v3 - **jumping straight from v1 works**:
   `moved.tf` chains both renames, Terraform replays the whole lineage in one plan.
2. `terraform plan` -> one `has moved to` line per hop, **no resource changes**.
3. `terraform apply` per environment, promoted like any other commit.

## What you do NOT do

- No `terraform state mv`, no per-environment runbook.
- No cleanup: the chain is the upgrade path, it stays for the lifetime of the major.
