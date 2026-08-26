# Terraform state refactoring - `moved`, `removed`, `import`

`lab` · tags: `terraform` `state` `moved` `removed` `import` `refactoring` `modules` `v1.7`

Refactor a live root module **without destroying anything**: rename a resource,
split the root into a platform-team module, absorb a `for_each` set, upgrade a
module that ships its own migration, chain moves across versions, and hand a
resource over to another team. Every step ends on the same target: a plan with
**zero resource changes**.

## How the lab is driven

One directory does the work, `live/`. It is the only one that ever holds a state
file, and it is the only one you `cd` into. Each step is a **complete snapshot**
of what `live/` should contain at that point, and one script swaps them in:

```sh
cd live
../scripts/switch.sh step-2     # prints the .tf diff, then replaces live/*.tf
```

The script touches **`.tf` files only**. `terraform.tfstate`,
`.terraform.lock.hcl` and `.terraform/` stay exactly where they are - that is the
whole trick: the state stays put while the code moves under it, which is what a
refactor really is. The printed diff is the lesson of the step; read it before
planning.

You never leave `live/`, and you keep typing plain Terraform commands. The script
does not run Terraform for you.

| Path | Role |
|---|---|
| `live/` | The working root - the only directory with a state. Starts at step 1. |
| `step-1` .. `step-6`, `step-5b` | Complete snapshots, one per gesture (all CI-validated). |
| `modules/app-config/{v1,v2,v3}` | The platform team's module, three published versions. v2/v3 ship `moved.tf` + `MIGRATION.md`. |
| `billing-team/` | Another team's root module, with **its own state file** - the other side of the step-6 handover. |
| `scripts/switch.sh` | Swaps a snapshot into `live/` and prints the diff. |

## Run it

```sh
mise install
cd live
terraform init
terraform apply                 # step 1 - the starting point, 4 SSM parameters
```

Then, for each step: swap, read the diff, plan, apply.

```sh
../scripts/switch.sh step-2
terraform plan                  # read the "has moved to" lines
terraform apply
```

`terraform init` is needed again whenever the **module source changes** - steps
3, 5 and 5b. Running it when it was not needed costs a second and changes
nothing, so when in doubt, run it.

## Steps

| Step | Gesture | Mechanism | What the plan shows | `init` first? |
|---|---|---|---|---|
| 1 | Starting point: flat root, drifted naming, a foreign resource | - | 4 parameters created | yes (first run) |
| 2 | Rename to the naming convention | `moved` (root) | `has moved to`, 0 change | no |
| 3 | Migrate the config parameter to the platform module | `moved` (consumer-written) | move into `module.app_config`, 0 change | **yes** |
| 4 | Absorb the `for_each` flag set | one `moved` on the resource address | one move **per instance**, 0 change | no |
| 5 | Module upgrade v1 -> v2 (internal rename) | `moved.tf` shipped BY the module | move replayed without touching this root | **yes** |
| 5b | Jump to v3 - even straight from v1 | chained `moved` blocks | the full lineage replays in one plan | **yes** |
| 6 | Hand the billing parameter to its owner | `removed` + `destroy = false`, then `import` in `billing-team/` | forgotten here, adopted there, never destroyed | no |

Step 5 and 5b are alternatives: 5 walks v1 -> v2 -> v3, 5b jumps v1 -> v3 in one
plan. Play whichever tells the story you want.

Between steps, `terraform state pull | jq '.resources[].name'` shows what the
refactor did to the state - and `git log` is the only history of the moves: an
applied `moved` block leaves **no trace** in the state.

## Step 6 in full - crossing a state boundary

`moved` edits one state; it cannot bridge two. Handing a resource to another team
is therefore a **pair** of blocks, one on each side:

```sh
# in live/ - step-6 declares `removed` with destroy = false
terraform apply      # the parameter leaves this state, AWS keeps it

cd ../billing-team   # a separate root, a separate state file
terraform init
terraform apply      # "Plan: 1 to import" -> "1 imported"
```

The resource is never destroyed and never recreated: only its owner changes. The
`import` block is a one-shot migration instruction - once applied, it can be
deleted.

## Rewind and teardown

After step 6, `live/` no longer manages the billing parameter, but the parameter
still exists on AWS. Replaying step 1 as-is therefore fails with
`ParameterAlreadyExists`. Two ways out.

**Rewind to replay the lab** - let the new owner take it, then drop it:

```sh
cd ../billing-team
terraform init && terraform apply     # adopts the parameter (import)
terraform destroy                     # removes it from AWS entirely
cd ../live && ../scripts/switch.sh step-1
terraform apply                       # recreates a clean starting point
```

**Teardown at the end** - same idea, in this order:

```sh
cd billing-team && terraform destroy   # the parameter it owns
cd ../live && terraform destroy        # everything else
```

If neither state manages the parameter and you want it gone:
`aws ssm delete-parameter --name /tf-state-refactoring/billing/export-bucket`.

## Producer / consumer rules demonstrated

- A **published module** ships its migrations (`moved.tf` + `MIGRATION.md`) and
  **keeps them for the lifetime of the major**: the chain is the upgrade path,
  removing a hop is a breaking change.
- A **root module** writes `moved` blocks for its own refactors and cleans them
  up once applied in every environment.
- `moved` requires the same resource type on both sides, and stays inside one
  state. Crossing a state boundary is `removed` + `import`.

## Troubleshooting

- `terraform init` is required after every switch that changes a module source
  (steps 3, 5, 5b).
- `ParameterAlreadyExists` after step 6: see "Rewind and teardown" above.
- The `billing-team/` import block hardcodes the default `name_prefix`; align it
  if you changed the variable.

## Going further

- [`terraform-query-import`](../terraform-query-import/) - the declarative
  `import` and `query` side of adopting existing infrastructure.
- [`terraform-secrets-out-of-state`](../terraform-secrets-out-of-state/) - what
  the state persists, and how to keep secrets out of it.

## References

- [Refactoring (moved blocks)](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) - rename/split/chain rules, instance keys, and why removing a `moved` block is a breaking change.
- [Remove a resource from state (removed block)](https://developer.hashicorp.com/terraform/language/state/remove) - `destroy = false` semantics and why the block beats `state rm`.
- [Refactor across state files](https://developer.hashicorp.com/terraform/language/state/refactor) - the `removed` + `import` handover and the `state mv -state-out` legacy path.
- [Import block](https://developer.hashicorp.com/terraform/language/import) - declarative adoption, previewable at plan.
- [aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) - the resource used everywhere here; its import id is the parameter name.
