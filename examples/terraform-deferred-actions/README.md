# terraform-deferred-actions

> **Type**: `experiment` &nbsp;·&nbsp; **Tags**: `rc` `deferred-actions` `kms` `unknown-at-plan`

A **before / after** comparison of Terraform's **deferred actions**, shown on one concrete problem: encrypting an S3 bucket with a KMS key whose **ARN is created in the same run** and is therefore **unknown at plan time**.

The generic child module decides how to encrypt the bucket based on whether a KMS key is provided. To decide, it needs a conditional (`count` on a validation data source). And that is exactly where the unknown value bites.

## The blocking point before 1.16

`count` and `for_each` could **not** depend on a value that is unknown at plan time. So you could not write the natural thing:

```hcl
# pre-1.16: errors when var.kms_key_arn is unknown at plan
data "aws_kms_key" "provided" {
  count  = var.kms_key_arn != null ? 1 : 0
  key_id = var.kms_key_arn
}
```

```
Error: Invalid count argument

  The "count" value depends on resource attributes that cannot be determined
  until apply, so Terraform cannot predict how many instances will be created.
```

**Workaround (`01-before/`)**: thread a second input that *is* known at plan - a `provided` boolean - alongside the ARN. The module keys its `count` on that boolean, not on the ARN:

```hcl
variable "kms" {
  type = object({
    arn      = optional(string) # may be unknown at plan
    provided = bool             # MUST be known at plan
  })
}

data "aws_kms_key" "provided" {
  count  = var.kms.provided ? 1 : 0   # known -> count is determinable
  key_id = var.kms.arn
}
```

The caller has to assert `provided = true` even though the ARN is unknown. Redundant, and the flag can silently disagree with the ARN.

## The resolution after 1.16

**Deferred actions** make unknown values usable in `count` / `for_each`: instead of failing the plan, Terraform **defers** the affected resources to apply. The natural code just works (`02-after/`):

```hcl
variable "kms_key_arn" {
  type    = string # may be unknown at plan - that's fine now
  default = null
}

data "aws_kms_key" "provided" {
  count  = var.kms_key_arn != null ? 1 : 0   # unknown -> deferred, not an error
  key_id = var.kms_key_arn
}
```

Single source of truth (just the ARN), no redundant `provided` flag. No `experiments` block is needed - the `unknown_instances` / `ephemeral_values` experiments have concluded and ship on by default.

You do, however, **opt into deferral at the CLI** by passing **`-allow-deferral`** to `terraform plan` / `apply`. With it, Terraform defers the affected resources to apply (shown as deferred changes in the plan output); **without it, the plan still errors** on the unknown value. The flag is the activation switch in this alpha - the `experiments` block is not.

## Layout

| Dir | Terraform | Module input | Encryption decision |
|-----|-----------|--------------|---------------------|
| [`01-before/`](01-before/) | `1.15.6` | `kms = object({ arn, provided })` | `count` keyed on the plan-known `provided` flag |
| [`02-after/`](02-after/)  | `1.16.0-alpha20260603` | `kms_key_arn = string` | `count` derived from `arn != null`; unknown deferred via `-allow-deferral` |

Each root creates `aws_kms_key.root` and feeds its (plan-unknown) ARN to a single bucket instance.

## Security baseline

Both roots aim to pass a static security scan (`trivy config`) cleanly, so the example stays a good starting point and not a source of bad habits:

- **KMS** - `aws_kms_key.root` enables annual key rotation (`enable_key_rotation = true`, clears `AWS-0065`). `deletion_window_in_days = 7` is the AWS minimum, kept short on purpose for fast demo teardown.
- **S3** - the bucket enforces SSE-KMS encryption, blocks all public access, and enables object versioning (`aws_s3_bucket_versioning`, clears `AWS-0090`).
- **Inputs** - `region` and `bucket_prefix` are `nullable = false` and validated, so a typo fails fast at plan time rather than at apply.

Knowingly out of scope (would bloat a teaching example): S3 access logging (`AWS-0089`, needs a log bucket) and VPC/flow-log style controls. These are documented rather than silenced.

## Prerequisites

- **Terraform version**: each dir pins it in its `mise.toml` (`01-before/` = 1.15.6, `02-after/` = 1.16.0-alpha...). With mise, `cd` selects it automatically (`mise install` once); otherwise switch manually and confirm with `terraform version`.
- **Credentials**: `validate` and `plan` need none. `apply` creates a real KMS key + S3 bucket, so authenticate first (replace `<profile>` with your SSO profile):

```bash
aws sso login --profile <profile>
export AWS_PROFILE=<profile>
```

## Run

With mise tasks (selects the version per dir, init included; `mise tasks` lists them):

```bash
mise run init           # init both dirs
mise run versions       # prove the resolved version per dir
mise run before-plan    # 1.15.6 - OK only thanks to the provided boolean
mise run before-apply   # 1.15.6 - apply (needs AWS creds)
mise run before-destroy # teardown
mise run after-plan     # 1.16   - deferred changes (-allow-deferral)
mise run after-apply    # 1.16   - apply (needs AWS creds)
mise run after-destroy  # teardown
```

Or the raw commands:

```bash
# before - run with Terraform 1.15.x
cd 01-before && terraform init && terraform plan   # works only thanks to provided = true

# after - run with Terraform 1.16+
cd 02-after && terraform init
terraform plan  -allow-deferral   # data source deferred to apply (plan errors without the flag)
terraform apply -allow-deferral
```

Deferral is a plan/apply-time behaviour; `terraform validate` (what CI runs) passes without credentials for both.
