# AGENTS.md - terraform-query-import example

Guidance for AI coding agents working inside this example. Repo-wide conventions live in the root
`AGENTS.md`; this file covers what is specific to `terraform-query-import`.

Taxonomy: **type `lab`** - progressive, playable in a live session. Tags: `aws`, `query`, `import`,
`tfquery`, `v1.14`.

## Purpose and scope

A **pedagogical demo** (live tech session, 35-40 min) of Terraform 1.14 **search**: discover
unmanaged infrastructure with `list` blocks (`.tfquery.hcl`), generate config with
`terraform query -generate-config-out`, and import it in bulk.

The demo deliberately creates real "ClickOps" infrastructure first (`bootstrap/`) and then brings it
under management. Keep resources cheap (t3.micro) and remind users to destroy.

## Architecture

- `bootstrap/` - shell scripts using the AWS CLI to create/destroy EC2 instances tagged
  `demo=clickops`, entirely **outside** Terraform. Two categories (`tier=general` t3.micro,
  `tier=compute` t3.small) feed the segmented-import demo. No `providers.tf` here, so CI ignores it.
- `import/` - the Terraform root module. `search.tfquery.hcl` holds two `list` blocks
  (`general` / `compute`, one per instance-type) to demo segmented bulk import; the
  `generated.tf` produced by `terraform query -generate-config-out` is **git-ignored** (a live
  artifact). The module ships with no `resource` blocks - they are generated during the demo.

## Common commands

```bash
# 1. create unmanaged infra
cd bootstrap && ./create-unmanaged.sh

# 2-4. discover, generate, import (from import/)
cd ../import
terraform init
terraform query
terraform query -generate-config-out=generated.tf
terraform plan && terraform apply

# teardown
terraform destroy            # if imported
# ../bootstrap/destroy-unmanaged.sh   # if NOT imported
```

Validation before committing: `terraform fmt -recursive` (root) and `terraform validate` in
`import/`. The `.tfquery.hcl` file is only read by `terraform query`, not by `validate`/`tflint`.

## Prerequisites

- Terraform `>= 1.14.0` (pinned to `1.14.9` in `.terraform-version`).
- AWS provider `6.41.0`, AWS CLI with credentials; default region `eu-west-1`.

## Conventions in this example

- `list` blocks live only in `*.tfquery.hcl` files; the `config` filter mirrors the provider's
  data-source filters (EC2 `DescribeInstances` filters here, e.g. `tag:demo`).
- Never commit `generated.tf` - it is regenerated each run and must be reviewed, not trusted.
- Keep `bootstrap/` free of `providers.tf` so CI does not attempt to validate/plan it.
