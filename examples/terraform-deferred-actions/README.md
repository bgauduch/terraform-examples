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

**Workaround (`before/`)**: thread a second input that *is* known at plan - a `provided` boolean - alongside the ARN. The module keys its `count` on that boolean, not on the ARN:

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

**Deferred actions** make unknown values usable in `count` / `for_each`: instead of failing the plan, Terraform **defers** the affected resources to apply. The natural code just works (`after/`):

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
| [`before/`](before/) | `1.15.6` | `kms = object({ arn, provided })` | `count` keyed on the plan-known `provided` flag |
| [`after/`](after/)  | `1.16.0-alpha20260603` | `kms_key_arn = string` | `count` derived from `arn != null`; unknown deferred via `-allow-deferral` |

Each root creates `aws_kms_key.root` and feeds its (plan-unknown) ARN to a single bucket instance.

```bash
# before - run with Terraform 1.15.x
cd before && terraform init && terraform plan   # works only thanks to provided = true

# after - run with Terraform 1.16+
cd after && terraform init
terraform plan  -allow-deferral   # data source deferred to apply (plan errors without the flag)
terraform apply -allow-deferral
```

Deferral is a plan/apply-time behaviour; `terraform validate` (what CI runs) passes without credentials for both.
