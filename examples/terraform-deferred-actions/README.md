# terraform-deferred-actions

> **Type**: `experiment` &nbsp;·&nbsp; **Tags**: `rc` `deferred-actions` `kms` `unknown-at-plan`
>
> Tracks a Terraform pre-release capability - pinned to `1.16.0-alpha20260603` via `.terraform-version`.

## Objective

Show how Terraform 1.16's **deferred actions** let a value that is **unknown at plan time** flow into a module without breaking the plan. Concretely: pass a KMS key ARN created in the same apply into a generic S3 module whose behaviour depends on that ARN.

## How it works

- **Root module** creates `aws_kms_key.root` and calls the generic `s3-bucket-encrypted` module **twice**:
  - `existing_key_bucket` - passes `aws_kms_key.root.arn`. That ARN is **unknown at plan**, so the module's `count`-driven data source is **deferred to apply** instead of failing the plan.
  - `managed_key_bucket` - passes nothing, exercising the default path.
- **Child module** `modules/s3-bucket-encrypted/` is generic and never creates a key:
  - `kms_key_arn` set - validates it via `data.aws_kms_key` and uses it for SSE-KMS.
  - `kms_key_arn` null - uses S3's default SSE-KMS managed key (`aws/s3`).

This is **native** in 1.16: no `experiments` block and no `-allow-deferral` flag (the `unknown_instances` / `ephemeral_values` experiments have concluded and are on by default).

```bash
terraform init
terraform plan    # the existing-key bucket's data source is deferred to apply
terraform apply
```

## Notes

- Bucket names get a `random_id` suffix for global uniqueness.
- Deferral is a plan/apply-time behaviour; `terraform validate` (what CI runs) passes without credentials.
