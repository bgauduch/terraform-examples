# terraform-actions

> **Type**: `lab`
> **Tags**: `aws` `actions` `lifecycle` `cloudfront` `v1.14`

Terraform **1.14** introduced **actions**: declarative, *imperative* side-effects you bind to a
resource's lifecycle. This lab shows a classic day-2 need - **invalidate a CloudFront cache
automatically whenever the page it serves changes** - using the **native**
`aws_cloudfront_create_invalidation` action, with no `null_resource` + `local-exec` hack.

## The idea

Two new language pieces work together:

1. An **`action` block** declares *what* to do (here: invalidate a distribution).
2. An **`action_trigger`** inside a resource's `lifecycle` declares *when* to run it.

```hcl
action "aws_cloudfront_create_invalidation" "invalidate" {
  config {
    distribution_id = aws_cloudfront_distribution.site.id
    paths           = ["/*"]
  }
}

resource "aws_s3_object" "index" {
  # ... uploads content/index.html ...
  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_cloudfront_create_invalidation.invalidate]
    }
  }
}
```

Available lifecycle events: `before_create`, `after_create`, `before_update`, `after_update`.

## Why not `local-exec`?

A `null_resource` + `local-exec "aws cloudfront create-invalidation ..."` works, but: it is not in
the plan, it depends on the `aws` CLI and ambient credentials on the runner, its triggering relies
on `triggers` hacks, and errors are opaque. Actions are **first-class**: shown in the plan, run by
the provider with the configured credentials, and bound to real lifecycle events.

## What gets deployed

- A **private** S3 bucket (origin), with public access blocked, versioning and SSE enabled.
- A **CloudFront distribution** (Origin Access Control) serving `index.html` over HTTPS.
- The `index.html` object, whose lifecycle triggers the cache invalidation.

## Security baseline

The config aims to pass `trivy config` on the gating findings. Three CloudFront findings are
knowingly **out of scope** for a teaching demo and silenced with documented `#trivy:ignore` lines
in `main.tf` (rather than hidden):

- **WAF** in front of the distribution (`AVD-AWS-0011`).
- **Access logging** to a dedicated log bucket (`AVD-AWS-0010`).
- **Minimum TLS version** (`AVD-AWS-0013`) - not settable with the default CloudFront certificate;
  enforcing it would require ACM + a custom domain, out of scope here.
- **Customer-managed KMS key** for the bucket (`AVD-AWS-0132`) - SSE-S3 (AES256) is appropriate for
  public web assets behind a CDN; SSE-KMS would also need a `kms:Decrypt` grant for the OAC.

## Prerequisites

- **Terraform `>= 1.14.0`** (pinned via `.terraform-version`; actions do not exist before 1.14).
- **AWS provider `6.41.0`** (the `aws_cloudfront_create_invalidation` action ships in the 6.x line).
- AWS credentials for `apply` (`validate`/`plan` need none). Default region: `eu-west-1`.

## Run (live demo)

```bash
terraform init
terraform apply        # creates the bucket + distribution + object;
                       # the after_create event fires the FIRST invalidation.

terraform output cloudfront_url   # open it -> shows "Content version: v1"
```

Then, live:

```bash
# Edit content/index.html: change "v1" to "v2".
terraform apply        # the after_update event fires a NEW invalidation;
                       # refresh the URL -> v2 is visible immediately.
```

Invoke the action **stand-alone** (run only the action, no infra change):

```bash
terraform apply -invoke=action.aws_cloudfront_create_invalidation.invalidate
```

Teardown:

```bash
terraform destroy
```

> A CloudFront distribution takes a few minutes to deploy and to tear down - factor that into the
> live timing. `terraform validate` (what CI runs) needs no credentials.

## Going further

- `terraform-actions-lambda` - same mechanism, but with `aws_lambda_invoke` as a generic escape
  hatch when no native provider action fits.
