# BOOTSTRAP — plan to initialize the demo

A self-contained checklist to stand up the cut-off demo on a sandbox account. Hand this to an
agent (or follow it by hand). It provisions the un-fun plumbing with Terraform; the interesting
moves stay manual (console + terminal) so they read well live.

## 0. Prerequisites (confirm first)

- **Management / org-admin access** (Budget Actions `APPLY_SCP_POLICY` are created from the org
  management or delegated-admin account). Without it, this plan does not apply — stop and reconsider.
- A **sandbox member account** in a non-prod OU, region `eu-west-1`.
- Two working AWS profiles (SSO): one for management, one for the sandbox.
- `mise` installed (toolchain SSOT).

## 1. Configure

```bash
cd examples/aws-budget-cutoff
mise install
cp env/example.tfvars terraform.tfvars
```

Fill `terraform.tfvars`: `mgmt_profile`, `sandbox_profile`, `mgmt_account_id`,
`sandbox_account_id`, `notify_email`. Leave `budget_limit_usd = "0.01"` so real spend already
exceeds it.

## 2. Apply — the EVENING BEFORE

Budgets needs one evaluation cycle (~8–12 h) to move the action to `PENDING`. Apply the night
before, not the morning of.

```bash
mise run init
mise run validate
mise run apply
```

Confirm the SNS email subscription (check the inbox, click confirm).

## 3. Post-apply checks

- Budget `sandbox-cutoff-demo` visible in the management account (Billing → Budgets).
- Budget action present, `execution_role_arn` set, approval `MANUAL`.
- SCPs `cutoff-surgical` and `cutoff-hard` exist in Organizations, **both unattached**.
- Runaway EC2 (`runaway-gpu-sim`, tag `demo=runaway`) running in the sandbox.
- Lambda `cutoff-remediation` invocable; SNS email subscription confirmed.

## 4. Arm check (morning of)

The action should read `PENDING` (budget exceeded + evaluated). Verify:

```bash
aws budgets describe-budget-action \
  --account-id <mgmt_account_id> --budget-name sandbox-cutoff-demo \
  --action-id "$(terraform output -raw budget_action_id)" --profile <mgmt_profile> \
  --query 'Action.Status'
```

- `PENDING` → approve it live via `terraform output -raw approve_action_cli`.
- still `STANDBY` → use `terraform output -raw manual_attach_cli` (attach the SCP directly).

## 5. Dry-run the walkthrough

```bash
MGMT_PROFILE=<mgmt> SANDBOX_PROFILE=<sandbox> ./scripts/steps.sh
```

Then re-apply (`mise run apply`) to recreate the runaway instance and re-arm before the real run.

## 6. Teardown

```bash
mise run destroy
```

Removes the budget/action/SCPs, the runaway EC2, and the remediation stack. Detach the SCP first if
a run left it attached (`manual_attach_cli` mirror: `attach-policy` → `detach-policy`).

## Notes

- Everything here is account-local and reproducible. Cost is negligible (t3.micro minutes, a few
  Lambda invokes, SNS emails).
- The full-auto prod trigger (EventBridge on `AttachPolicy`) is intentionally not built — see
  README "Full-auto wiring".
