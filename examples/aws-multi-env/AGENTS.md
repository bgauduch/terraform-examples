# AGENTS.md - aws-multi-env example

Guidance for AI coding agents working inside this example. Repo-wide conventions live in the root `AGENTS.md`; this file covers what is specific to `aws-multi-env`.

Taxonomy: **type `pattern`** - a reusable, side-by-side reference. Tags: `aws`, `multi-env`, `backend`, `workspaces`.

## Purpose and scope

This is a **pedagogical demo** (supporting content for the "Matinale Tech" Twitch live stream), not production code. It illustrates four progressive patterns for managing multiple environments with Terraform CE on AWS. Configuration is deliberately minimal to keep focus on the multi-env structure itself.

Key implication: do not introduce production hardening (remote backend, locking, CI/CD, secrets management, strict version pinning) unless the user explicitly asks. The README's "Demo only" callout lists what would be added for real use - treat that as out-of-scope by default.

## Architecture: the four levels

Each `level-*/` directory is an independent root module demonstrating one multi-env pattern. They are intentionally **not** factored into a shared codebase - the duplication between levels is the point, since it lets a reader compare approaches side by side.

All levels deploy the same trivial topology (VPC + public subnet + private subnet, tagged `Project`/`Environment`/`ManagedBy`). The network code is the backdrop; the *structural* differences between levels are the lesson.

- **level-0-single-env/**: flat root module, one state, one env. Baseline.
- **level-1-workspaces/**: single root module, env selected via `terraform.workspace`. Per-env config lives in a `locals` map resolved with `lookup()`. Demonstrates the approach the official docs discourage for multi-env.
- **level-2-root-per-env/**: `dev/` and `prod/` are separate root modules consuming a shared `modules/network/`. Full state isolation at the cost of root-code duplication.
- **level-3-specialization/**: single root module, env injected at runtime via `-backend-config=env/<env>.backend.hcl` and `-var-file=env/<env>.tfvars`. Switching env locally requires `terraform init -reconfigure`.

When editing one level, keep changes scoped to that level unless the user explicitly asks to propagate a pattern. Cross-level consistency is *not* a goal - each level is a standalone teaching artifact.

## Common commands

Always `cd` into the relevant `level-*/` directory first. The README has per-level command sequences; the canonical ones:

```bash
# Levels 0, 1, 2 (standard)
terraform init
terraform plan
terraform apply
terraform destroy

# Level 1 workspaces
terraform workspace new <env> && terraform workspace select <env>

# Level 3 specialization (env passed at CLI)
terraform init -backend-config=env/<env>.backend.hcl
terraform plan  -var-file=env/<env>.tfvars
terraform apply -var-file=env/<env>.tfvars
# switching env locally:
terraform init -reconfigure -backend-config=env/<other>.backend.hcl
```

Validation before committing: `terraform fmt -recursive` and `terraform validate` (run inside each level directory for `validate`).

## Prerequisites

- Terraform >= 1.5.0 (pinned via this example's `mise.toml`)
- AWS CLI with valid credentials
- Default region: `eu-west-1`

## Conventions in this example

- Provider-defined functions from AWS provider v1.8+ are intentionally showcased (`provider::aws::arn_parse`, `provider::aws::arn_build`); keep them when touching surrounding code.
- Subnet CIDRs are always computed via `cidrsubnet(vpc_cidr, 8, N)` rather than hardcoded - preserve this pattern when extending.
- Tags are composed with `merge(local.common_tags, { Name = ... })` - follow the same shape for new resources.
