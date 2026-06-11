# terraform-rc-variables

> **Type**: `experiment` &nbsp;·&nbsp; **Tags**: `rc` `deferred-actions` `kms` `unknown-at-plan`
>
> Experimental and intentionally unstable - this example tracks a Terraform release-candidate feature and will be fleshed out live.

## Objective

Exercise Terraform's experimental **deferred actions** to simplify passing variables whose value is **not known at plan time**.

Concrete scenario: inject a **KMS key into a module via an ARN that is dynamic and not necessarily known during `plan`** (e.g. the key is created in the same apply). Today this forces awkward workarounds (two-phase applies, `-target`, placeholder values). Deferred actions let the plan tolerate the unknown value and defer the affected resources to apply.

## The feature

Deferred actions are enabled by passing `-allow-deferral` to `terraform plan`. They let `count` and `for_each` (in `module`, `resource`, and `data` blocks) carry unknown values and allow providers to react more flexibly to unknowns, instead of erroring out at plan time.

```bash
terraform init
terraform plan -allow-deferral -var 'kms_key_arn=<arn-or-unknown>'
```

## Status

Scaffold only. Before the live:

- [ ] Bump `.terraform-version` to the target Terraform RC that ships deferred actions.
- [ ] Wire the KMS key + consuming module so the ARN is genuinely unknown at plan.
- [ ] Demonstrate the plan succeeding with `-allow-deferral` vs failing without it.

The current files only surface the `kms_key_arn` input so the example validates and is picked up by CI.
