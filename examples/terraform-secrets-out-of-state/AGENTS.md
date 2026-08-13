# AGENTS.md - terraform-secrets-out-of-state example

Guidance for AI coding agents working inside this example. Repo-wide conventions live in the root
`AGENTS.md`; this file covers what is specific to `terraform-secrets-out-of-state`.

Taxonomy: **type `lab`** - progressive, playable in a live session. Tags: `aws`, `secrets`,
`ephemeral`, `write-only`, `rotation`, `v1.11`.

## Purpose and scope

A **pedagogical demo**. It walks the four native mechanisms for keeping a secret out of the state,
one at a time, where each step ends on the defect the next one removes. The pedagogy *is* the
progression: do not collapse the steps into a single correct configuration.

## Architecture

Two root modules (both auto-discovered by CI through their `providers.tf`):

- **Root** - the walkthrough. `app.tf` is invariant (secret container, Lambda consumer, scoped IAM,
  log group). `secret.tf` is the only file that moves, and ships with **step 1 active**, the
  anti-pattern, with steps 2 to 6 as commented blocks.
- **`final/`** - the target state alone (ephemeral `random_password` feeding `secret_string_wo`),
  readable without the walkthrough. This is what a reader should copy.

## Invariants - do not break these

- **`secret.tf` is the only file that changes.** The whole point is that the consumer never moves
  while the write path changes six times. Never add a step that touches `app.tf`.
- **Steps 3 and 5 must fail.** They are the lesson, not a defect. They can never be the active step,
  because CI runs `validate` on whatever is uncommitted.
- **Every value is throwaway.** No real credential ever lands here, not even briefly. The JSON blob
  is shaped like a chat-bot credential set so the example reads as realistic while staying inert.
- **The Lambda returns a fingerprint, never the value.** A truncated SHA-256 is enough to watch a
  rotation happen and useless to anyone intercepting it.
- **The consumer receives `SECRET_ARN`, never the secret.** Terraform wires the reference and the
  IAM permission; the value is resolved at runtime by the consumer.

## Common commands

```bash
terraform init
terraform apply                                       # step 1
eval "$(terraform output -raw state_proof_command)"   # the token, in clear
eval "$(terraform output -raw fingerprint_command)"   # what the consumer reads
# walk secret.tf step by step, re-running the proof
terraform destroy
```

Validation before committing: `terraform fmt -recursive` (root) and `terraform validate` in both
this directory and `final/`.

## Prerequisites

- Terraform `>= 1.11.1` (pinned in `mise.toml`) - 1.11 is the floor for write-only arguments
  (`ephemeral` blocks land in 1.10), and 1.11.0 breaks step 4: sensitive+ephemeral into a
  write-only argument fails plan serialization (hashicorp/terraform#36619).
- AWS provider `~> 6.0`, `random ~> 3.7`, `archive ~> 2.0`. AWS credentials for `apply`.
  Default region `eu-west-1`.

## Conventions in this example

- `recovery_window_in_days = 0` on the secret so the destroy/re-apply loop works back to back. The
  README says explicitly that production keeps the default 7-day window - keep that caveat.
- Measured behaviour stays measured: the migration section of the README reports what was observed
  on this resource and this provider version. If a claim there changes, re-run it before editing.
- Tags via `local.common_tags` (`Project` / `ManagedBy`).
- Error messages quoted in comments and README are verbatim Terraform output. Do not paraphrase
  them - they are the teaching material.
