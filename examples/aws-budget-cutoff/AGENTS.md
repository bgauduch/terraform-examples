# AGENTS.md — aws-budget-cutoff

Example-specific guidance. Inherits the repo-root `AGENTS.md` (toolchain, git flow, standards).

## Type

`lab` — a runnable starting point for a tech session. Progressive on purpose: configure → trigger →
freeze → remediate → rollback.

## Shape

- Two providers: default `aws` = **management** account (Organizations SCPs + Budgets), `aws.sandbox`
  = the **member** account (runaway EC2, break-glass role, remediation stack). Every resource picks
  its provider explicitly.
- Files are split by concern: `scp.tf`, `budget.tf`, `runaway.tf`, `remediation.tf`. Keep that split.
- The **critical path** is `budget.tf` only (budget + action + exec role). SNS/Lambda in
  `remediation.tf` are an optional off-critical-path layer — do not fold them into the critical path.

## Constraints

- **Management/org-admin access required** to apply. CI only runs `validate` + `tflint` + `trivy`
  (no apply, no creds), so keep the config valid without credentials.
- Region-locked to `eu-west-1` (a pre-existing sandbox SCP blocks other regions). Do not add
  resources in another region.
- SCPs stay **unattached** in code — the Budget Action attaches them. Never add an
  `aws_organizations_policy_attachment` for the cut-off SCPs.
- Break-glass exemption (`aws:PrincipalArn` `ArnNotLike`) must survive any SCP edit — anti-lock-out.

## Tests

`tests/validations.tftest.hcl` is creds-free (input-variable `expect_failures` only). The
org/budget/SCP layer needs a real management account and is validated by `terraform validate` + a
real apply, not by a unit test. Do not add mocked plan tests that require the two providers to
authenticate.
