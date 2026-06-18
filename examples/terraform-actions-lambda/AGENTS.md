# AGENTS.md - terraform-actions-lambda example

Guidance for AI coding agents working inside this example. Repo-wide conventions live in the root
`AGENTS.md`; this file covers what is specific to `terraform-actions-lambda`.

Taxonomy: **type `lab`** - progressive, playable in a live session. Tags: `aws`, `actions`,
`lambda`, `dynamodb`, `v1.14`.

## Purpose and scope

A **pedagogical demo** (live tech session, 30-45 min). It shows Terraform 1.14 actions used as
a **generic escape hatch**: `action "aws_lambda_invoke"` runs arbitrary logic (here a DynamoDB
on-demand backup) on a resource lifecycle event. Companion to `terraform-actions`, which uses a
native provider action.

Keep it minimal and focused on the action → Lambda mechanism. Do not swap the Lambda for the native
`aws_dynamodb_create_backup` action: going through Lambda is the whole lesson (call it out, do not
"optimise" it away).

## Architecture

Single root module (`providers.tf` is auto-discovered by CI). Flow:

`aws_dynamodb_table.this` → `lifecycle.action_trigger` → `action "aws_lambda_invoke".backup` →
`aws_lambda_function.backup` (+ IAM role/policy, log group, zipped `lambda/backup.py`).

**Cycle avoidance (important):** the Lambda must not depend on the table, or
`table → action → lambda → table` becomes a cycle that `terraform validate` rejects. The IAM policy
scopes `dynamodb:CreateBackup` to `local.table_arn` (built from `var.region` + caller account id +
table name), never `aws_dynamodb_table.this.arn`. Keep it that way.

## Common commands

```bash
terraform init
terraform apply                 # after_create -> first backup
# change a table attribute, then:
terraform apply                 # after_update -> new timestamped backup
terraform apply -invoke=action.aws_lambda_invoke.backup   # stand-alone, on-demand backup
terraform destroy
```

Validation before committing: `terraform fmt -recursive` (root) and `terraform validate` here.

## Prerequisites

- Terraform `>= 1.14.0` (pinned in `.terraform-version`).
- AWS provider `6.41.0` (carries the `aws_lambda_invoke` action); `archive` provider zips the Lambda.
- AWS credentials for `apply`; default region `eu-west-1`.

## Conventions in this example

- `events` are bare identifiers (`after_create`, not `"after_create"`).
- IAM is least-privilege: `dynamodb:CreateBackup` on the table ARN, logs to the function's own group.
- The Lambda zip lands in `build/` (git-ignored) via the `archive_file` data source.
- Tags via `local.common_tags` (`Project` / `ManagedBy`); follow the same shape for new resources.
