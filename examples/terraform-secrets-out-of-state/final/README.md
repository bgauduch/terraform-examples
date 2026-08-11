# final - the target state, on its own

The end state of the [`terraform-secrets-out-of-state`](../) lab, without the walkthrough that
gets there. **This is the module to copy.**

Terraform generates the secret, hands it to the vault through a write-only argument, and keeps
nothing: not in the state, not in the plan, not in the logs. No human ever sees the value.

```hcl
ephemeral "random_password" "app" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id                = aws_secretsmanager_secret.app.id
  secret_string_wo         = ephemeral.random_password.app.result
  secret_string_wo_version = var.secret_version
}
```

Three things carry the whole pattern:

- **`ephemeral`** produces a value Terraform is structurally forbidden from persisting. It is opened
  on every plan and every apply, and never written down.
- **`secret_string_wo`** is a write-only argument: the provider receives the value at apply time and
  Terraform discards it. It is the only way an ephemeral value can reach a managed resource.
- **`secret_string_wo_version`** is what *does* land in state. Terraform cannot diff a value it never
  kept, so this number carries your intent. Increment it to rotate.

## Run

```bash
terraform init
terraform apply
eval "$(terraform output -raw state_proof_command)"   # has_secret_string_wo: true, no value

terraform apply -var secret_version=2                 # rotate
```

The bump **replaces** the resource, which is correct: a secret version is immutable, so rotating
creates a new one. `AWSCURRENT` moves to it and the previous version becomes `AWSPREVIOUS`.

## Before you copy this

- **A write-only argument only exists where the provider implements it**, attribute by attribute.
  Check the registry page for your resource before assuming.
- **There is no drift detection on the value.** Change the secret without bumping the version and
  nothing is sent, silently.
- **Never derive the version from `timestamp()` or a uuid.** It is persisted, so that means a
  perpetual diff and a replacement on every plan.
- **Scheduled rotation belongs to the vault**, not to Terraform. See
  `aws_secretsmanager_secret_rotation`. The useful consequence of write-only is that, with no value
  in state, native rotation and Terraform stop fighting over it.
- `recovery_window_in_days = 0` here so the module can be destroyed and re-applied back to back.
  **Production keeps the default 7-day window.**

## Migrating an existing secret

Swapping `secret_string` for `secret_string_wo` on a resource that already exists is measured and
documented in the [parent README](../README.md#migrating-an-existing-secret), including the upstream
bug that affects another resource. Short version: migrating cleans the present, not the history.
Rotate the secret, then migrate.
