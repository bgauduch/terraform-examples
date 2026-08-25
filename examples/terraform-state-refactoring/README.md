# Terraform state refactoring - `moved`, `removed`, `import`

`lab` · tags: `terraform` `state` `moved` `removed` `import` `refactoring` `modules` `v1.7`

Refactor a live root module **without destroying anything**: rename a resource,
split the root into a platform-team module, absorb a `for_each` set, upgrade a
module that ships its own migration, chain moves across versions, and hand a
resource over to another state. Every step ends on the same target: a plan with
**zero resource changes**.

## Layout

| Path | Role |
|---|---|
| `live/` | The working root - the only directory with a real state. Starts at step 1. |
| `step-1` .. `step-6`, `step-5b` | Complete snapshots, one per gesture (all CI-validated). |
| `modules/app-config/{v1,v2,v3}` | The platform team's module, three published versions. v2/v3 ship `moved.tf` + `MIGRATION.md`. |
| `adjacent/` | The billing team's root - a separate state, target of the step-6 handover. |
| `scripts/switch.sh` | Overlays a snapshot into `live/` - the state stays put. |

## Run

```sh
mise install
cd live
terraform init
terraform apply            # step 1 - the starting point (4 SSM parameters)
cd ..
scripts/switch.sh step-2   # then: cd live && terraform init && terraform plan
```

## Steps

| Step | Gesture | Mechanism | What the plan proves |
|---|---|---|---|
| 1 | Starting point: flat root, drifted naming, a foreign resource | - | 4 parameters created |
| 2 | Rename to the naming convention | `moved` (root) | `has moved to`, 0 change |
| 3 | Migrate the config parameter to the platform module | `moved` (consumer-written) | move into `module.app_config`, 0 change |
| 4 | Absorb the `for_each` flag set | one `moved` on the resource address | every instance moves, 0 change |
| 5 | Module upgrade v1 -> v2 (internal rename) | `moved.tf` shipped BY the module | move replayed without touching this root |
| 5b | Jump to v3 - even straight from v1 | chained `moved` blocks | the full lineage replays in one plan |
| 6 | Hand the billing parameter to its owner | `removed` + `destroy = false`, then `import` in `adjacent/` | forgotten here, adopted there, never destroyed |

Between steps, `terraform state pull | jq '.resources[].name'` shows what the
refactor did to the state - and `git log` is the only history of the moves:
an applied `moved` block leaves no marker in the state.

## Producer / consumer rules demonstrated

- A **published module** ships its migrations (`moved.tf` + `MIGRATION.md`) and
  **keeps them for the lifetime of the major**: the chain is the upgrade path,
  removing a hop is a breaking change.
- A **root module** writes `moved` blocks for its own refactors and cleans them
  up once applied in every environment.
- `moved` cannot cross state files and requires the same resource type on both
  sides. The cross-state workflow is `removed` (without destroy) + `import`.

## Troubleshooting

- `terraform init` is required after every switch that changes a module source.
- The `adjacent/` import block hardcodes the default `name_prefix`; align it if
  you changed the variable.

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
