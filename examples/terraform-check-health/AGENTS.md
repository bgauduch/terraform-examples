# AGENTS.md - terraform-check-health example

Guidance for AI coding agents working inside this example. Repo-wide conventions live in the root
`AGENTS.md`; this file covers what is specific to `terraform-check-health`.

Taxonomy: **type `lab`** - progressive, playable in a live session. Tags: `aws`, `check`, `drift`,
`post-apply`, `v1.5`.

## Purpose and scope

A **pedagogical demo** (Twitch / LinkedIn live, 25-30 min). It illustrates Terraform 1.5 `check`
blocks: post-apply assertions on the **real** deployed website, and out-of-band **drift detection**
that surfaces as a non-blocking warning on the next `plan`.

Keep it minimal and fast (a public S3 website, no CDN) so the apply → break → plan-warns → fix loop
fits a short live slot. Do not turn the `check` into a `precondition`/`postcondition`: the lesson is
that checks **warn** instead of blocking.

## Architecture

Single root module (`providers.tf` is auto-discovered by CI):

- Public S3 static website (`aws_s3_bucket` + website config + public-read policy) serving
  `content/index.html`.
- One `check "website_health"` with a scoped `data "http"` and two `assert`s (status 200 + body
  marker). The data source is re-read on every plan/apply, which is what catches drift.

## Common commands

```bash
terraform init
terraform apply                 # check runs, passes
# tamper with the live object via the AWS CLI (see README), then:
terraform plan                  # check emits a WARNING, exit code stays 0
terraform apply                 # restores managed content, check green again
terraform destroy
```

Validation before committing: `terraform fmt -recursive` (root) and `terraform validate` here.
`validate` does not execute the `http` data source, so it needs no network/credentials.

## Prerequisites

- Terraform `>= 1.5.0` (pinned in `.terraform-version`; `check` and `strcontains` both land in 1.5).
- AWS provider `~> 5.0` + `http` provider; AWS credentials for `apply`. Default region `eu-west-1`.

## Conventions in this example

- The bucket is intentionally public; keep ACL public-access blocked and document the two relaxed
  policy guards with `#trivy:ignore` (`AVD-AWS-0093`, `AVD-AWS-0087`) - do not silence silently.
- Assertions reference the scoped `data.http.home`; keep the data source inside the `check` block so
  it is re-read each run (drift detection depends on this).
- Tags via `local.common_tags` (`Project` / `ManagedBy`).
