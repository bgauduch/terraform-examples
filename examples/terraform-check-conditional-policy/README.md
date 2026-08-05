# terraform-check-conditional-policy

> **Type**: `lab`
> **Tags**: `aws` `check` `kms` `iam` `multi-env` `v1.5`

A KMS key policy whose administrators depend on **what actually exists in the account**. An
optional platform role is folded into the admin list when it is there, and a Terraform **1.5
`check` block** turns its absence into a **warning** instead of a silent gap - so the
environments where the role was never rolled out still deploy.

## The problem

A platform baseline (an ops role, a break-glass role, a CI role) rarely lands in every account at
the same time. Two usual answers, both unsatisfying:

- **Hardcode the ARN** - `terraform plan` fails in every account that lacks the role.
- **Look it up and move on** - the key ships with a shorter admin list, and nobody finds out.

## The pattern

Two halves that are often confused. Only the second one is a `check`.

**1. Compose conditionally** - the *plural* data source returns an empty set instead of failing:

```hcl
# `aws_iam_role` (singular) ERRORS when the role is missing and fails the plan.
# `aws_iam_roles` (plural) returns an empty set - which is what makes it optional.
data "aws_iam_roles" "ops" {
  name_regex = "^${var.ops_role_name}$"
}

locals {
  ops_role_arns        = tolist(data.aws_iam_roles.ops.arns)
  key_admin_principals = concat([local.account_root], local.ops_role_arns)
}
```

**2. Make the assumption observable** - the `check` says out loud what the config just swallowed:

```hcl
check "ops_role_present" {
  assert {
    condition     = length(local.ops_role_arns) > 0
    error_message = "Role '${var.ops_role_name}' is absent from this account: the KMS key policy was rendered without it."
  }
}
```

The data source sits at **top level**, not scoped inside the `check`: the key policy consumes it,
and a check-scoped data source is only visible inside its own `check`.

## Why `check` and not `precondition`

| | On a missing role |
|---|---|
| `precondition` / `postcondition` | **errors** - every account without the baseline is blocked |
| `check` | **warns** - the gap is reported on every plan, the deployment proceeds |

The role's absence is a legitimate state in some environments, so it is a **signal**, not a gate.
That is the whole distinction the `check` block exists for.

## What gets deployed

- One `aws_kms_key` + alias, with a key policy granting administration to the account root plus
  the ops role **when it resolves**.
- One `check "ops_role_present"` re-evaluating the lookup on every plan and apply.

Outputs expose what was actually rendered: `key_admin_principals` and `ops_role_detected`.

## Prerequisites

- **Terraform `>= 1.5.0`** (pinned via `mise.toml`; `check` blocks do not exist before 1.5).
- AWS provider `~> 5.0`. AWS credentials for `apply` (`validate` needs none). Default region:
  `eu-west-1`.
- The ops role is **not managed here** - that is the point. Create it out of band to play the
  happy path.

## Run

Roll out the platform role the key expects (a bare role, no attached policy, so it deletes
cleanly):

```bash
aws iam create-role --role-name demo-ops-admin \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
```

Deploy - the role resolves, its ARN lands in the key policy, the check passes:

```bash
terraform init
terraform apply
terraform output key_admin_principals   # account root + the ops role ARN
```

Now retire the role behind Terraform's back, the way an account that never received the baseline
looks:

```bash
aws iam delete-role --role-name demo-ops-admin

terraform plan; echo "exit=$?"
```

The plan reports **two different things at once**, and they are worth separating:

- a **resource diff** on the key policy - the ARN disappears from the admin list, because the
  lookup is re-read and the config genuinely renders differently;
- a **check warning** - `Role 'demo-ops-admin' is absent from this account...` - and **`exit=0`**.

Roll the role back out and the warning goes away:

```bash
aws iam create-role --role-name demo-ops-admin \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
terraform plan    # no warning - but still one change to make
terraform apply   # reconciles, and the next plan is clean
```

> **Why the extra apply.** Deleting an IAM principal referenced in a resource policy makes AWS
> freeze it as its **unique ID** (`AROA...`) rather than drop it - the ARN only resolves while the
> principal exists. A recreated role gets a *new* unique ID, so the policy AWS holds and the policy
> Terraform renders genuinely differ until you apply. The check is quiet by then: it asserts on the
> role's existence, which is true again.

No credentials to spare for IAM writes? Point the variable at a name that cannot exist and the
same warning fires on `plan` alone:

```bash
terraform plan -var 'ops_role_name=role-that-does-not-exist'
```

## Teardown

```bash
terraform destroy
aws iam delete-role --role-name demo-ops-admin
```

> A KMS key is **scheduled** for deletion, not deleted: `deletion_window_in_days = 7` is the
> minimum AWS allows. `destroy` returns immediately, the key lingers as `PendingDeletion` (and
> free) until the window elapses. Cancel with `aws kms cancel-key-deletion --key-id <id>`.

## References

- [`check` block](https://developer.hashicorp.com/terraform/language/block/check) - syntax, and why
  failures are warnings rather than errors.
- [Custom conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions) -
  `precondition` / `postcondition` / `check` side by side; the gate-versus-signal call this lab makes.
- [Health assessments (HCP Terraform)](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/health) -
  continuous validation, for re-evaluating this assumption on a schedule instead of only on plan.
- [`terraform validate`](https://developer.hashicorp.com/terraform/language/validate) - why the CI
  gate needs no credentials: it never resolves the data sources.
- [`aws_iam_roles` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) -
  the plural lookup that returns an empty set instead of failing.
- [KMS key policies](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html) - why
  `kms:*` scoped to the key plus a root delegation is the documented baseline.
- [IAM unique identifiers](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html) -
  the `AROA...` IDs behind the extra apply after a role is recreated.
