# AGENTS.md - terraform-module-testing

Example-specific guidance. Repo-wide conventions: root AGENTS.md.

Taxonomy: **type lab** - progressive stages. Tags: aws, terraform-test, testing, s3, validation, mock, parallel.

## Purpose and scope

Demonstrate the native `terraform test` framework on a reusable S3 module: validate inputs, fail cleanly (`expect_failures`), test the plan without the cloud (`mock_provider`), deploy for real and assert resources, parallelize with `state_key`. Pedagogical, not a production library.

## Architecture

- `modules/s3-bucket/`: the module under test (child). Simple validations (S3 name, environment) + cross-variable ones (encryption ⇒ KMS ARN; `force_destroy` allow-listed per env, deny-by-default). Conditional KMS encryption (`count` on the ARN).
- root (`main.tf` + `providers.tf`): example usage (root) + per-run `default_tags` for the sweeper.
- `tests/`:
  - `validations.tftest.hcl`: `expect_failures`, plan-only, creds-free (mock).
  - `plan.tftest.hcl`: `mock_provider`, assertions on the planned config, creds-free.
  - `deploy.tftest.hcl`: real apply (requires AWS_PROFILE), resource assertions, auto-destroy.
  - `parallel.tftest.hcl`: `parallel` + `state_key`, 2 concurrent deployments.
  - `setup/`: helper module (random suffix for unique names).

## Progressive demo

The README is structured as a progressive demo climbing the test pyramid: Stage 0 (read the module) → Stage 1 validations → Stage 2 mocked plan → Stage 3 real apply → Stage 4 parallel. Each stage maps to a pyramid layer and a `mise` task. Keep that mapping in sync when editing the README, the `mise.toml` tasks, or the test files.

## Common commands

```bash
mise run init
mise run test-validate          # Stage 1 - validations only (creds-free)
mise run test-plan              # Stage 2 - mocked plan only (creds-free)
mise run test-fast              # Stages 1+2 (CI without secret)
mise run test                   # full suite, real apply (requires AWS_PROFILE)
./sweep.sh                      # clean orphans by tag (dry-run)
```

## Conventions

- Prefer multiple single-type variables over one complex `object`. A custom `validation` reports against the whole variable, never the offending attribute (still a gap in 1.15), so single-type variables keep each error message specific and each `run` atomic. Native type/required-attribute errors do name the attribute - only custom rules don't.
- Interpolate the rejected value into `error_message` (Terraform 1.6+) for context - see the `environment` validation. Since 1.9 the diagnostic also echoes the values the condition referenced.
- One atomic `run` per validator (easy to read, cheap plan-only).
- S3 `versioning` = `Enabled` / `Suspended` (never `Disabled`).
