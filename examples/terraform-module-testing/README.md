# terraform-module-testing

> **type** `lab` · **tags** `aws` `terraform-test` `testing` `s3` `validation` `mock` `parallel`

Test a Terraform module with the native `terraform test` framework, as a **progressive live demo**: validate the inputs, break it on purpose, plan it without the cloud, then deploy it for real and assert the resources. Companion to the "Terraform test" live (2026-06-25). No Go, pure HCL.

## The test pyramid (rather, a diamond)

Native `terraform test` covers the bottom and middle of the pyramid; the top (e2e, polling, retries) stays out of scope and belongs to Terratest. The stages below climb that pyramid, each demo stage maps to one layer:

| Pyramid layer | Stage | What it proves | Cloud / creds | `make` target |
|---|---|---|---|---|
| Static (lint/scan) | - | syntax, security, policy | none | `fmt` `validate` (+ CI tflint/trivy) |
| Unit-ish: validation | **1** | inputs fail fast (`expect_failures`) | none (mock) | `test-validate` |
| Unit-ish: plan | **2** | variables wire into the planned config (`mock_provider`) | none (mock) | `test-plan` |
| Integration | **3** | real apply, resources assert, auto-destroy | yes | `test-deploy` |
| Integration: scale | **4** | `parallel` + `state_key`, concurrent deploys | yes | `test-parallel` |
| E2e / polling | - | out of native scope → Terratest | - | - |

The first two stages run **without credentials** (CI without secrets). The last two deploy on a real account and `terraform test` destroys at the end of each file. Authenticate first and export your profile (replace `<profile>` with your SSO profile):

```bash
aws sso login --profile <profile>
export AWS_PROFILE=<profile>
```

## Stage 0 - read the module (no test yet)

`modules/s3-bucket/` creates an S3 bucket with versioning, public-access blocking and conditional SSE-KMS encryption. It encodes decisions as guardrails:

- **simple validations**: bucket name (S3 rules), `environment` (dev/staging/prod);
- **cross-variable validations** (Terraform 1.9+): `enable_encryption` requires `kms_key_arn`; `force_destroy` is allowed only in an allow-listed environment (`local.force_destroy_allowed_envs`, deny-by-default);
- **conditional encryption**: `count = local.kms_enabled ? 1 : 0`, where `kms_enabled = var.enable_encryption && var.kms_key_arn != null` (the flag arms it, the ARN is required by the cross-validation).

The root (`main.tf` + `providers.tf`) is an example usage and the configuration under test. Open these first: the point is that a module is decisions you can prove.

## Stage 1 - validations (fail fast, creds-free)

`tests/validations.tftest.hcl` - one atomic `run` per validator, `command = plan`, `expect_failures` against each `var.*`. The validation halts before any provider call, so the layer is credential-free.

```bash
make test-validate              # 6 runs green, no AWS_PROFILE
```

**Red → green demo**: comment out the cross-validation on `enable_encryption` in `modules/s3-bucket/variables.tf`, rerun: the `encryption_requires_kms_key` run goes red (its `expect_failures` is no longer satisfied). Restore the validation, rerun: green again. The test pins the guardrail.

## Stage 2 - plan with `mock_provider` (creds-free)

`tests/plan.tftest.hcl` - `mock_provider "aws" {}` plus a file-level `variables {}` block that sets defaults for every `run`. Assertions on the planned config: versioning defaults to `Enabled`, all four public-access-block flags are true, the encryption block is present/absent and the KMS ARN propagates.

```bash
make test-plan                  # 4 runs green in seconds, still no credentials
make test-fast                  # stages 1+2 combined (the CI layer)
```

## Stage 3 - real apply (integration)

`tests/deploy.tftest.hcl` - `command = apply` on a real account. A `setup` helper module mints a random suffix for a globally unique bucket name; assertions run against the real outputs; `terraform test` destroys everything at the end of the file.

```bash
make test-deploy                # uses your exported AWS_PROFILE
```

## Stage 4 - parallel runs (`state_key`)

`tests/parallel.tftest.hcl` - the same example deployed twice concurrently. `parallel = true` (Terraform 1.12+) plus a distinct `state_key` (1.11+) isolate the state of each run, so they run at the same time without collision.

```bash
make test-parallel
make test                       # the full 15-run suite (apply + auto-destroy)
```

## Cleanup on crash

If `terraform test` is interrupted before its auto-destroy, the in-memory state is lost and the resources leak. Every resource carries a suite tag (`default_tags`), so a sweeper can find them:

```bash
./sweep.sh            # list tagged buckets (dry-run)
./sweep.sh --force    # empty + delete
```

Native `skip_cleanup` + `terraform test cleanup` land as a preview in Terraform 1.16.

## Beyond native testing

Layer the tools, lightest first: static (`tflint`/`trivy`, every commit) → `terraform test` (unit mock + integration apply, this lab) → Terratest when e2e/polling is required. `terraform test` returns an exit code, so stages 1+2 gate a merge in CI without any secret.
