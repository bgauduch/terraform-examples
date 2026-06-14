# Repo lessons

Durable lessons learned while working in this repository. Append new entries; keep them short and actionable.

## CI

- **Trivy single-scan + convert** - run `trivy config . --format json --output trivy.json --exit-code 0` once, then drive both the report and the gate from that one JSON with `trivy convert`: `--severity MEDIUM,HIGH,CRITICAL --exit-code 0` for visibility and `--severity HIGH,CRITICAL --exit-code 1` to block. Scanning once and converting twice keeps a single source of truth and avoids re-scanning per severity. Install the CLI with the pinned `aquasecurity/setup-trivy` action (pin the trivy `version:` too) rather than the all-in-one `trivy-action`, so the raw `trivy` commands are available in the step. Pin trivy to a version already proven in CI (e.g. the one `trivy-action` bundles): a brand-new patch can fail to install via setup-trivy's `get.trivy.dev` path before it is mirrored there.

## Security hardening

- **KMS rotation (`AWS-0065`)** - `trivy config` flags `aws_kms_key` without `enable_key_rotation = true`. Always enable rotation on customer-managed keys; pair it with a deliberately short `deletion_window_in_days` (AWS minimum is 7) only in throwaway demos, with a comment explaining why.
- **S3 versioning (`AWS-0090`)** - an encrypted, private bucket still trips the scanner without an `aws_s3_bucket_versioning` resource set to `Enabled`. Versioning is a separate resource, not an inline block on `aws_s3_bucket`.
- **Variable validation** - mark required inputs `nullable = false` and add a `validation {}` block (region regex, `cidrhost()` for CIDRs, `contains()` allow-lists for enums). Failures then surface at plan time with a clear message instead of as opaque provider errors at apply.
- **Documented exceptions** - low-value scanner findings that would bloat a teaching example (S3 access logging `AWS-0089`, VPC flow logs `AWS-0178`) are documented in the example README rather than silenced with inline ignores.

## Dependency management

- **Dependabot blind spots** - the `github-actions` ecosystem only updates `uses:` refs (and syncs the `# vX.Y.Z` comment beside a pinned SHA). It cannot bump tool versions held in action *inputs* (`tflint_version`, setup-trivy `version:`) or in `.terraform-version` files.
- **Renovate fills them** - Renovate `customManagers` (regex) bump those fields. For inputs, drop a `# renovate: datasource=github-releases depName=<owner/repo>` annotation on the line above the version. For `.terraform-version` (which can't hold a comment), match the file by name and set `datasource`/`depName`/`versioning` in the manager itself. Freeze intentional RC/alpha pins (the `experiment` examples) with a `packageRule` on `matchCurrentValue: "/-(alpha|beta|rc)/"`.
- **Validate before merge** - `npx --package renovate renovate-config-validator .github/renovate.json` catches schema errors locally; the Mend app uses the in-repo config (no onboarding PR) once present.
