# terraform-check-conditional-policy

> **Type**: `lab`
> **Tags**: `aws` `check` `precondition` `kms` `iam` `multi-env` `v1.5`

One module, many accounts, a platform baseline that reaches them at different times. Two roles
this key policy would like to grant administration to, and the same question asked about each:
*what if this account does not have it yet?*

The answers differ, and that difference is the lab.

| Role | If absent | Block | Rationale |
|---|---|---|---|
| **break-glass** | the apply **stops** | `precondition` | policy calls for a named, audited emergency path on a key of this class |
| **platform admin** | the apply **proceeds**, a warning is raised | `check` | accounts mid-migration legitimately lag; the key is fine without it |

`precondition` and `check` are the same assertion machinery pointed at the same kind of fact. What
separates them is the verdict you are willing to hand down, and that is a governance call rather
than a technical one.

## The mechanics

The lookup that feeds the policy uses the **plural** data source:

```hcl
# `aws_iam_role` (singular) ERRORS when the role is missing and fails the plan.
# `aws_iam_roles` (plural) returns an empty set - which is what makes it optional.
data "aws_iam_roles" "platform_admin" {
  name_regex = "^${var.platform_admin_role_name}$"
}
```

The check re-reads the same role through **its own scoped data source** (`checks.tf`):

```hcl
check "platform_admin_role_present" {
  data "aws_iam_roles" "platform_admin_observed" {
    name_regex = "^${var.platform_admin_role_name}$"
  }

  assert {
    condition     = length(data.aws_iam_roles.platform_admin_observed.arns) > 0
    error_message = "..."
  }
}
```

Two lookups of the same role is deliberate. A scoped data source is **invisible outside its own
check**, so it can never feed the policy - and that constraint is the point: the check observes
reality on every run instead of trusting what the configuration computed.

## The key policy

Five statements, following the AWS key-policy baseline. It exists so the conditional part above
governs something worth governing.

| # | Sid | Grants |
|---|---|---|
| 1 | `EnableIAMUserPermissions` | the documented root delegation - it lets IAM policies govern the key, and keeps it administrable |
| 2 | `KeyAdministration` | an explicit action list (never `kms:*`, which would hand administrators `Decrypt`) to one permanent admin plus whichever baseline roles this account has |
| 3 | `KeyUsageByApplicationViaS3` | encrypt/decrypt to the application role, under `kms:ViaService` - a leaked credential cannot call `Decrypt` directly, the request has to arrive through S3 |
| 4 | `AllowGrantsForAWSServices` | `CreateGrant` under `kms:GrantIsForAWSResource`, which is how S3 encrypts objects on the caller's behalf |
| 5 | `DenyOutsideOrganization` | denies everyone outside `aws:PrincipalOrgID`, sparing AWS service principals via `BoolIfExists aws:PrincipalIsAWSService` |

> **Statement 5 deserves respect.** A `Deny` in a key policy also governs who may edit that policy,
> so a miscalibrated condition leaves the key unrecoverable. It sits behind `var.enable_org_deny`
> for that reason - validate it on a throwaway key before trusting it. Without the
> `PrincipalIsAWSService` exception, S3 itself gets denied: service principals carry no
> `aws:PrincipalOrgID`, so `StringNotEquals` matches them.

## Layout

```
main.tf        cross-cutting locals and data sources
iam.tf         baseline role lookups + the application identity
kms.tf         the five-statement key policy, the key, and the break-glass precondition
s3.tf          a bucket encrypted with the key, so the policy governs real traffic
checks.tf      the check block
bootstrap/     the platform baseline, as a separate root module
```

## Prerequisites

- **Terraform `>= 1.5.0`** (floor declared in `required_version`; `check` blocks do not exist before 1.5).
- AWS provider `~> 5.0`. AWS credentials for `apply` (`validate` needs none). Default region:
  `eu-west-1`.
- An account inside an AWS Organization (statement 5 reads the org ID).

## Run

`bootstrap/` stands in for the platform baseline. Applying it means *this account received the
baseline*; destroying it means *this one is still waiting*.

```bash
cd bootstrap && terraform init && terraform apply && cd ..
terraform init
terraform apply
terraform output key_admin_principals    # permanent admin + both baseline roles
```

Objects land encrypted under the key, which is what makes statements 3 and 4 real:

```bash
echo hello > /tmp/t.txt
aws s3 cp /tmp/t.txt "s3://$(terraform output -raw bucket_name)/t.txt"
aws s3api head-object --bucket "$(terraform output -raw bucket_name)" --key t.txt \
  --query '{sse:ServerSideEncryption,kms:SSEKMSKeyId,bucketKey:BucketKeyEnabled}'
```

### The role that may be missing: a signal

```bash
aws iam delete-role --role-name demo-platform-admin
terraform plan; echo "exit=$?"
```

The output flips (`platform_admin = true -> false`), the ARN leaves the admin statement, the check
warns, and **`exit=0`**. An account mid-migration deploys.

### The role that may not: a gate

```bash
aws iam delete-role --role-name demo-break-glass
terraform plan; echo "exit=$?"
```

`Error: Resource precondition failed`, and **`exit=1`**. Nothing deploys.

### Back to a healthy account

```bash
cd bootstrap && terraform apply && cd ..
terraform apply     # reconciles, and the next plan is clean
```

> **Why that apply is needed.** Deleting an IAM principal referenced in a resource policy makes AWS
> freeze it as its **unique ID** (`AROA...`) rather than drop it - the ARN only resolves while the
> principal exists. A recreated role gets a *new* unique ID, so the policy AWS holds and the policy
> Terraform renders genuinely differ until you apply.

## Teardown

```bash
terraform destroy
cd bootstrap && terraform destroy
```

> A KMS key is **scheduled** for deletion, not deleted: `deletion_window_in_days = 7` is the
> minimum AWS allows. `destroy` returns immediately, the key lingers as `PendingDeletion` (and
> free) until the window elapses. Cancel with `aws kms cancel-key-deletion --key-id <id>`.

## References

- [`check` block](https://developer.hashicorp.com/terraform/language/block/check) - syntax, scoped
  data sources, and why failures are warnings rather than errors.
- [Custom conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions) -
  `precondition` / `postcondition` / `check` side by side; the gate-versus-signal call this lab makes.
- [Health assessments (HCP Terraform)](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/health) -
  continuous validation, for re-evaluating these assumptions on a schedule instead of only on plan.
- [`terraform validate`](https://developer.hashicorp.com/terraform/language/validate) - why the CI
  gate needs no credentials: it never resolves the data sources.
- [`aws_iam_roles` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) -
  the plural lookup that returns an empty set instead of failing.
- [KMS key policies](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html) - the
  baseline the five statements follow, starting with the root delegation.
- [KMS policy conditions](https://docs.aws.amazon.com/kms/latest/developerguide/policy-conditions.html) -
  `kms:ViaService` and `kms:GrantIsForAWSResource`, behind statements 3 and 4.
- [`aws:PrincipalOrgID`](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html) -
  the organization perimeter in statement 5, and which principals carry the key.
- [IAM unique identifiers](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html) -
  the `AROA...` IDs behind the extra apply after a role is recreated.
