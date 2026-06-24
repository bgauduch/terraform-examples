# AGENTS.md - terraform-module-testing

Example-specific guidance. Repo-wide conventions: root AGENTS.md.

Taxonomy: **type lab** - live support, progressive stages. Tags: aws, terraform-test, testing, s3, validation, mock, parallel.

## Purpose and scope

Demonstrate the native `terraform test` framework on a reusable S3 module: validate inputs, fail cleanly (`expect_failures`), test the plan without the cloud (`mock_provider`), deploy for real and assert resources, parallelize with `state_key`. Pedagogical, not a production library.

## Architecture

- `modules/s3-bucket/`: the module under test (child). Simple validations (S3 name, environment) + cross-variable ones (encryption ⇒ KMS ARN; prod ⇒ no `force_destroy`). Conditional KMS encryption (`count` on the ARN).
- root (`main.tf` + `providers.tf`): example usage (root) + per-run `default_tags` for the sweeper.
- `tests/`:
  - `validations.tftest.hcl`: `expect_failures`, plan-only, creds-free (mock).
  - `plan.tftest.hcl`: `mock_provider`, assertions on the planned config, creds-free.
  - `deploy.tftest.hcl`: real apply (AWS_PROFILE=sandbox), resource assertions, auto-destroy.
  - `parallel.tftest.hcl`: `parallel` + `state_key`, 2 concurrent deployments.
  - `setup/`: helper module (random suffix for unique names).

## Progressive demo

The README is structured as a progressive live demo climbing the test pyramid: Stage 0 (read the module) → Stage 1 validations → Stage 2 mocked plan → Stage 3 real apply → Stage 4 parallel. Each stage maps to a pyramid layer and a `make` target. Keep that mapping in sync when editing the README, the `Makefile` targets, or the test files.

## Common commands

```bash
make init
make test-validate              # Stage 1 - validations only (creds-free)
make test-plan                  # Stage 2 - mocked plan only (creds-free)
make test-fast                  # Stages 1+2 (CI without secret)
AWS_PROFILE=sandbox make test    # full suite, real apply
./sweep.sh                      # clean orphans by tag (dry-run)
```

## Conventions

- Single-type variables rather than complex objects: isolates each validator's error message.
- One atomic `run` per validator (easy to read, cheap plan-only).
- S3 `versioning` = `Enabled` / `Suspended` (never `Disabled`).
