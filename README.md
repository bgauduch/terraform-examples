# Terraform Examples

[![Terraform quality](https://github.com/bgauduch/terraform-examples/actions/workflows/terraform.yml/badge.svg?branch=main)](https://github.com/bgauduch/terraform-examples/actions/workflows/terraform.yml)
[![Release](https://github.com/bgauduch/terraform-examples/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/bgauduch/terraform-examples/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/bgauduch/terraform-examples?sort=semver&display_name=tag)](https://github.com/bgauduch/terraform-examples/releases/latest)

A library of self-contained Terraform examples: reusable patterns, illustrations for blog/LinkedIn posts, and starting points for live tech sessions ("Matinale Tech").

Each example lives under [`examples/`](examples/) and is fully independent - its own `README.md`, tooling (`.terraform-version`, `.tflint.hcl`) and Terraform code. Pick one, `cd` into it, follow its README.

## Catalogue

| Example | Type | Tags | Description |
|---------|------|------|-------------|
| [`aws-multi-env`](examples/aws-multi-env/) | `pattern` | `aws` `multi-env` `backend` `workspaces` | Four progressive patterns for managing multiple environments with Terraform CE on AWS. |
| [`terraform-deferred-actions`](examples/terraform-deferred-actions/) | `experiment` | `rc` `deferred-actions` `kms` `unknown-at-plan` | Testing Terraform's experimental *deferred actions* (`plan -allow-deferral`) to inject a KMS key whose ARN is unknown at plan time. |
| [`terraform-query-import`](examples/terraform-query-import/) | `lab` | `aws` `query` `import` `tfquery` `v1.14` | Discover unmanaged infrastructure with `terraform query` + `list` blocks, generate its config, and import it in bulk. |

### Taxonomy

- `pattern` - reusable, production-leaning reference.
- `lab` - starting point / TP with progressive steps for a live session.
- `experiment` - preview/RC features, may be intentionally unstable.

## Adding an example

See the golden path in [`AGENTS.md`](AGENTS.md). In short: create `examples/<name>/` with its own `README.md`, `.terraform-version`, `.tflint.hcl` and Terraform root module(s), then add a row to the catalogue above. CI auto-discovers any directory containing `providers.tf` - no CI change needed.

## Repository standards

- **Git flow**: GitHub flow (short-lived branches off `main`, PR review, squash-merge).
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/); use the example name as scope (`feat(aws-multi-env): ...`).
- **Versioning**: [SemVer](https://semver.org/), repo-level single release line via release-please.
- **Validation before commit**: `terraform fmt -recursive` (root) and `terraform validate` inside each touched root module.
