# Migration guide

Upgrade notes for the `app-config` module, **newest first**: read the hop you are
on at the top, then keep scrolling for the earlier ones if you are catching up
from an older version.

Jumping several majors at once works: `moved.tf` chains every rename, so a v1
consumer moving straight to v3 replays the whole lineage in a single plan.

## v2 -> v3

### What changes

Internal rename: `aws_ssm_parameter.app_config` -> `aws_ssm_parameter.this`.
No variable, output, or parameter name changes.

### What you do

1. Bump the module source/version to v3.
2. `terraform plan` -> one `has moved to` line per hop you are crossing, and
   **no resource changes**.
3. `terraform apply` per environment, promoted like any other commit.

### What you do NOT do

- No `terraform state mv`, no per-environment runbook.
- No cleanup: the chain is the upgrade path, it stays for the lifetime of the major.

## v1 -> v2

### What changes

Internal rename: `aws_ssm_parameter.config` -> `aws_ssm_parameter.app_config`.
No variable, output, or parameter name changes.

### What you do

1. Bump the module source/version to v2.
2. `terraform plan` -> expect one line per environment:
   `aws_ssm_parameter.config has moved to aws_ssm_parameter.app_config`
   and **no resource changes**.
3. `terraform apply` in each environment. Same commit, every environment: the
   migration is code, promotion propagates it.

Heading straight to v3 instead? Skip this hop: the chain in `moved.tf` replays it
for you in the same plan.

### What you do NOT do

- No `terraform state mv`. The module ships the move in `moved.tf`.
- No cleanup on your side: the `moved` block lives in the module and stays there
  (removing it would break consumers still on v1).
