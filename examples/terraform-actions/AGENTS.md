# AGENTS.md - terraform-actions example

Guidance for AI coding agents working inside this example. Repo-wide conventions live in the root
`AGENTS.md`; this file covers what is specific to `terraform-actions`.

Taxonomy: **type `lab`** - progressive, playable in a live session. Tags: `aws`, `actions`,
`lifecycle`, `cloudfront`, `v1.14`.

## Purpose and scope

A **pedagogical demo** (supporting content for a Twitch / LinkedIn live, 30-45 min). It illustrates
Terraform 1.14 **actions**: binding the native `aws_cloudfront_create_invalidation` action to an
S3 object's lifecycle so the CDN cache is invalidated on every content change.

Keep it minimal and focused on the action mechanism. Do not add production hardening (WAF, access
logging, custom ACM domain) unless asked - those are documented as out-of-scope in the README and
silenced with `#trivy:ignore` lines.

## Architecture

Single root module (this directory; `providers.tf` is auto-discovered by CI). Flow:

`random_id` → `aws_s3_bucket` (private, OAC-only) → `aws_cloudfront_distribution` →
`action "aws_cloudfront_create_invalidation"` → `aws_s3_object.index` whose `lifecycle.action_trigger`
runs the action on `after_create` / `after_update`.

The action references the distribution; the object's trigger references the action. Terraform
orders the action after the distribution exists - do not add explicit `depends_on` for this.

## Common commands

```bash
terraform init
terraform apply                 # after_create -> first invalidation
# edit content/index.html, then:
terraform apply                 # after_update -> new invalidation
terraform apply -invoke=action.aws_cloudfront_create_invalidation.invalidate   # stand-alone
terraform destroy
```

Validation before committing: `terraform fmt -recursive` (root) and `terraform validate` here.

## Prerequisites

- Terraform `>= 1.14.0` (pinned in `.terraform-version`).
- AWS provider `6.41.0` (carries the CloudFront invalidation action).
- AWS credentials for `apply`; default region `eu-west-1`.

## Conventions in this example

- Prefer the **native provider action** over Lambda/local-exec; the Lambda escape-hatch variant
  lives in `terraform-actions-lambda`.
- `events` are bare identifiers (`after_create`, not `"after_create"`).
- Bucket stays private (OAC + bucket policy scoped to the distribution ARN); never make it public.
- Tags via `local.common_tags` (`Project` / `ManagedBy`); follow the same shape for new resources.
