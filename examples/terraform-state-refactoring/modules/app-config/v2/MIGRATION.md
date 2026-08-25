# app-config v1 -> v2

## What changes

Internal rename: `aws_ssm_parameter.config` -> `aws_ssm_parameter.app_config`.
No variable, output, or parameter name changes.

## What you do

1. Bump the module source/version to v2.
2. `terraform plan` -> expect one line per environment:
   `aws_ssm_parameter.config has moved to aws_ssm_parameter.app_config`
   and **no resource changes**.
3. `terraform apply` in each environment. Same commit, every environment: the
   migration is code, promotion propagates it.

## What you do NOT do

- No `terraform state mv`. The module ships the move in `moved.tf`.
- No cleanup on your side: the `moved` block lives in the module and stays there
  (removing it would break consumers still on v1).
