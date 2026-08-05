# AGENTS.md - terraform-check-conditional-policy example

Guidance for AI coding agents working inside this example. Repo-wide conventions live in the root
`AGENTS.md`; this file covers what is specific to `terraform-check-conditional-policy`.

Taxonomy: **type `lab`** - progressive, playable in a live session. Tags: `aws`, `check`, `kms`,
`iam`, `multi-env`, `v1.5`.

## Purpose and scope

A **pedagogical demo** illustrating the *governance* face of Terraform 1.5 `check` blocks, as
opposed to the health-probe face covered by `terraform-check-health`: an optional platform role is
folded into a KMS key policy when it exists in the account, and the `check` reports its absence as
a **warning** so accounts without the baseline still deploy.

Keep the two labs distinct. This one is about an **environment assumption made observable**; the
other is about **post-apply health and out-of-band drift**. Do not merge them, and do not add an
HTTP probe here.

## Architecture

Single root module (`providers.tf` is auto-discovered by CI):

- `data "aws_iam_roles" "ops"` - **plural on purpose**: it returns an empty set when nothing
  matches, where the singular `aws_iam_role` errors and fails the plan. Never swap it for the
  singular form; the optionality of the lookup depends on it.
- The data source stays at **top level**, not scoped inside the `check`, because the key policy
  consumes its result - a check-scoped data source is only visible inside its own `check`.
- `aws_kms_key` + alias, admins = account root `concat` the resolved ops role ARNs.
- `check "ops_role_present"` with a single `assert` on `length(local.ops_role_arns) > 0`.

## Common commands

```bash
aws iam create-role --role-name demo-ops-admin \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
terraform init && terraform apply    # role resolves, check passes
aws iam delete-role --role-name demo-ops-admin
terraform plan; echo "exit=$?"       # policy diff + check WARNING, exit 0
terraform destroy
```

Validation before committing: `terraform fmt -recursive` (root) and `terraform validate` here.
`validate` does not resolve the data sources, so it needs no network/credentials.

## Prerequisites

- Terraform `>= 1.5.0` (pinned in `mise.toml`; `check` blocks land in 1.5).
- AWS provider `~> 5.0`; AWS credentials for `apply`. Default region `eu-west-1`.

## Conventions in this example

- The ops role is **deliberately unmanaged** here: it models a baseline owned by another stack or
  team. Do not add a resource that creates it - the lab would lose its subject, and a role created
  in the same run is not visible to a data source read earlier in the same plan.
- Do not turn the `check` into a `precondition`: the lesson is that the role's absence is a
  legitimate state that warrants a warning, not a blocked apply.
- `kms:*` on `resources = ["*"]` inside a key policy is the documented KMS pattern (the policy is
  already scoped to its own key); keep the comment explaining it rather than narrowing it.
- `deletion_window_in_days = 7` is the AWS minimum - keep it so repeated demo runs stay cheap.
- Tags via `local.common_tags` (`Project` / `ManagedBy`).
