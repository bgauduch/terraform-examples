# Repo lessons

Durable lessons learned while working in this repository. Append new entries; keep them short and actionable.

## CI

- **Trivy single-scan + convert** - run `trivy config . --format json --output trivy.json --exit-code 0` once, then drive both the report and the gate from that one JSON with `trivy convert`: `--severity MEDIUM,HIGH,CRITICAL --exit-code 0` for visibility and `--severity HIGH,CRITICAL --exit-code 1` to block. Scanning once and converting twice keeps a single source of truth and avoids re-scanning per severity. The `trivy` CLI is installed by `mise` (pinned in the repo-root `mise.toml`), so the raw `trivy` commands are available in the step - no separate `setup-trivy`/`trivy-action`.

- **Lint commits on `pull_request`, never on `push`** - `wagoid/commitlint-github-action` lints `before..after` on a push event. After a rebase or force-push that range spans commits already on `main` (the release-please bodies carry a `Co-authored-by: github-actions[bot] <...>` trailer over the 100-char `footer-max-line-length`), turning a conforming PR red for history it does not own. The `pull_request` event lints `base..head` instead - the commits the PR actually proposes. Same job name, so branch protection is unaffected.

## Security hardening

- **KMS rotation (`AWS-0065`)** - `trivy config` flags `aws_kms_key` without `enable_key_rotation = true`. Always enable rotation on customer-managed keys; pair it with a deliberately short `deletion_window_in_days` (AWS minimum is 7) only in throwaway demos, with a comment explaining why.
- **S3 versioning (`AWS-0090`)** - an encrypted, private bucket still trips the scanner without an `aws_s3_bucket_versioning` resource set to `Enabled`. Versioning is a separate resource, not an inline block on `aws_s3_bucket`.
- **Variable validation** - mark required inputs `nullable = false` and add a `validation {}` block (region regex, `cidrhost()` for CIDRs, `contains()` allow-lists for enums). Failures then surface at plan time with a clear message instead of as opaque provider errors at apply.
- **Documented exceptions** - low-value scanner findings that would bloat a teaching example (S3 access logging `AWS-0089`, VPC flow logs `AWS-0178`) are documented in the example README rather than silenced with inline ignores.

## Dependency management

- **mise is the toolchain SSOT** - terraform, tflint and trivy versions live in `mise.toml` (repo root for shared tools, per-example for the `terraform` override), never in `.terraform-version` files or per-tool CI inputs. mise merges every `mise.toml` from the cwd to the repo root, so an example only restates what it changes. CI installs them via `jdx/mise-action`; locally `mise install` + `mise exec`/`mise run` resolve the right versions per directory.
- **Renovate's native `mise` manager** bumps the tools in `mise.toml` automatically - no custom manager needed for them. Keep a regex `customManager` only for versions that still live in action inputs (e.g. the `# renovate: datasource=github-releases depName=jdx/mise` annotation pinning the mise CLI in `tf-setup`). Freeze intentional RC/alpha pins (the `experiment` examples) with a backend-agnostic `packageRule` on `matchCurrentValue: "/-(alpha|beta|rc)/"` (match the value, not the dep name, since the mise backend may report a different `depName`).
- **mise + air-gapped/policy-restricted networks** - mise's `aqua` backend verifies tflint/trivy via cosign + GitHub artifact attestations, which reach `sigstore.dev`/`tuf-repo-cdn.sigstore.dev`; a `terraform` exact pin instead downloads straight from HashiCorp (no sigstore). If a sandbox blocks sigstore, exact-version installs of aqua tools fail there even though GitHub-hosted CI succeeds - it is an egress limitation, not a config defect.
- **Validate before merge** - `npx --package renovate renovate-config-validator .github/renovate.json` catches schema errors locally; the Mend app uses the in-repo config (no onboarding PR) once present.

## Custom conditions (precondition / postcondition / check)

- **A `check` earns its place only on a fact Terraform does NOT manage** - asserting on a managed
  attribute is dead weight: the drift already surfaces as a resource diff, and the pending change
  makes Terraform defer the check to apply time (`Check block assertion known after apply`), by
  which point the apply has reconciled the very thing the check was watching. Found the hard way on
  a `key_state == "Enabled"` assertion over `aws_kms_key.is_enabled`; the check never fired once.
- **A scoped data source is invisible outside its own check**, so anything a resource consumes needs
  a second, top-level lookup. That duplication is a feature, not a smell: the top-level read feeds
  the configuration, the scoped read observes reality on every run.
- **Use the plural data source for optional lookups** - `aws_iam_roles` returns an empty set where
  `aws_iam_role` errors and fails the plan. That difference is what lets one module deploy across
  accounts at different baseline stages.
- **Gate versus signal is a governance call, not a technical one.** Same assertion machinery, same
  kind of fact; what changes is the verdict you are willing to hand down. State the policy reason in
  the `error_message`, not just the condition.

## AWS gotchas

- **Deleting an IAM principal referenced in a resource policy freezes it as its unique ID** - AWS
  rewrites the ARN to `AROA...` rather than dropping the entry, because the ARN only resolves while
  the principal exists. Recreating the role mints a *new* unique ID, so the policy AWS holds and the
  policy Terraform renders genuinely differ until the next apply. Expect one extra apply after any
  role recreation.
- **A KMS key in active use can still be disabled or scheduled for deletion** - AWS does not track
  whether a key is in use and blocks nothing. Disabling a key that encrypts a live S3 bucket is
  accepted immediately; the bucket then fails `PutObject` with `KMS.DisabledException`.
- **An organization-perimeter `Deny` needs `BoolIfExists aws:PrincipalIsAWSService`** - AWS service
  principals carry no `aws:PrincipalOrgID`, so `StringNotEquals` matches them and the deny takes out
  the service that was supposed to use the key. And since a `Deny` in a key policy also governs who
  may edit that policy, a miscalibrated condition leaves the key unrecoverable: validate on a
  throwaway key, and keep the statement behind a variable.
