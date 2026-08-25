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
- `adjacent/` is a second, independent state (the billing team's root) used by
  the step-6 handover.

## Rules

- Parameter names and values must stay identical across steps: every step's
  target is a plan with **zero resource changes** (moves/forgets only). A diff
  that touches infrastructure is a bug in the step.
- Keep resources to SSM parameters: fast, near-free, no teardown traps.
- The repo never references the live sessions that use it (decoupling rule).
