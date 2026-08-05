# AGENTS.md - terraform-check-conditional-policy example

Guidance for AI coding agents working inside this example. Repo-wide conventions live in the root
`AGENTS.md`; this file covers what is specific to `terraform-check-conditional-policy`.

Taxonomy: **type `lab`** - progressive, playable in a live session. Tags: `aws`, `check`,
`precondition`, `kms`, `iam`, `multi-env`, `v1.5`.

## Purpose and scope

A **pedagogical demo** of the *governance* face of custom conditions, as opposed to the health-probe
face covered by `terraform-check-health`. One module deployed across accounts at different baseline
stages asks the same question about two roles and answers it two different ways:

- **break-glass absent** -> `precondition` on `aws_kms_key`, the apply stops.
- **platform admin absent** -> `check`, the apply proceeds with a warning.

That asymmetry IS the lesson. Keep both, and keep them opposite - collapsing them into one verdict
removes the point of the example.

## Architecture

Two root modules, both auto-discovered by CI (each holds a `providers.tf`):

- **root** - the key, its policy, the bucket that uses it, and the conditions.
- **`bootstrap/`** - the platform baseline (`demo-platform-admin`, `demo-break-glass`). Separate on
  purpose: applying it means "this account received the baseline", destroying it means "not yet".
  Never fold these roles into the root module - a role created in the same run is invisible to a
  data source read earlier in the same plan, and the example would lose its subject.

File split (per-service, following `aws-budget-cutoff`):

| File | Holds |
|---|---|
| `main.tf` | cross-cutting locals, `aws_caller_identity` / `aws_partition` / `aws_organizations_organization`, `random_id` |
| `iam.tf` | the two baseline role lookups, the application role and its bucket policy |
| `kms.tf` | key-policy document (5 statements), the key, its alias, the break-glass `precondition` |
| `s3.tf` | the bucket encrypted with the key |
| `checks.tf` | the `check` block |

## Invariants

- `data "aws_iam_roles"` is **plural on purpose**: it returns an empty set when nothing matches,
  where the singular `aws_iam_role` errors and fails the plan. Never swap it for the singular form;
  the optionality of the lookup depends on it.
- The policy-feeding lookups stay at **top level**; the check re-reads the same role through its
  own **scoped** data source. The duplication is deliberate - a scoped data source is invisible
  outside its check, and the check is meant to observe reality rather than the config's locals.
- Key administration uses an **explicit action list**, never `kms:*` - that wildcard would also
  grant `Decrypt` and `GenerateDataKey` to administrators.
- Statement 5 (`DenyOutsideOrganization`) stays behind `var.enable_org_deny`, and its
  `BoolIfExists aws:PrincipalIsAWSService` condition is **load-bearing**: AWS service principals
  carry no `aws:PrincipalOrgID`, so removing it denies S3 and breaks the bucket. A `Deny` in a key
  policy also governs edits to that policy, so a mistake here is unrecoverable.
- `deletion_window_in_days = 7` is the AWS minimum - keep it so repeated demo runs stay cheap.
- Tags via `local.common_tags` (`Project` / `ManagedBy`).

## Common commands

```bash
cd bootstrap && terraform init && terraform apply && cd ..
terraform init && terraform apply           # both roles present, no warning

aws iam delete-role --role-name demo-platform-admin
terraform plan; echo "exit=$?"              # check WARNING, exit 0

aws iam delete-role --role-name demo-break-glass
terraform plan; echo "exit=$?"              # precondition ERROR, exit 1

cd bootstrap && terraform apply && cd .. && terraform apply   # reconcile
```

Validation before committing: `terraform fmt -recursive` (root) and `terraform validate` in both
root modules. `validate` resolves no data sources, so it needs no network or credentials.
