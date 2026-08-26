# AGENTS.md - terraform-state-refactoring

Example-specific guidance. Read the repo-root `AGENTS.md` first.

## What this example is

`lab` - progressive steps demonstrating declarative state refactoring: `moved`
blocks (rename, split to a module, for_each set, versioned module migrations,
chained moves), then the cross-state handover (`removed` + `import`).

## Layout contract

- `live/` is the **only** root that ever holds a real state. It starts as a copy
  of `step-1` and mutates during a session via `scripts/switch.sh <step>`.
- `step-1` .. `step-6` (+ `step-5b`) are **complete snapshots**, one per gesture.
  All are CI-validated. A step change means updating BOTH the snapshot and, if
  it is the starting point, `live/`.
- Step dirs sit at the same depth as `live/` on purpose: module sources
  (`../modules/app-config/vN`) resolve identically before and after a switch.
  Do not nest them under a `steps/` folder.
- `modules/app-config/{v1,v2,v3}` simulate published module versions. v2 and v3
  ship `moved.tf` + `MIGRATION.md`: that pairing IS the lesson - never strip a
  `moved` block from a version, the chain is the upgrade path.
- `billing-team/` is a second, independent state: the root module of the team
  that owns the stray parameter, and the receiving side of the step-6 handover.
  The directory is named after the **owner**, not after its position - the whole
  point of step 6 is that a state boundary is an ownership boundary.

## Rules

- Parameter names and values must stay identical across steps: every step's
  target is a plan with **zero resource changes** (moves/forgets only). A diff
  that touches infrastructure is a bug in the step.
- Keep resources to SSM parameters: fast, near-free, no teardown traps.
- Step 6 leaves the billing parameter unmanaged by `live/`. Any rewind or
  teardown therefore goes through `billing-team/` first - the README section
  "Rewind and teardown" is the procedure, keep it in sync with the steps.
- The README is the entry point: it must always state how `switch.sh` is driven
  and which steps need a fresh `terraform init` (module source changes: 3, 5, 5b).
- The repo never references the live sessions that use it (decoupling rule).
