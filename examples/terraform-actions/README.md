# terraform-actions

> **Type**: `lab`
> **Tags**: `aws` `actions` `lifecycle` `cloudfront` `v1.14`

Terraform **1.14** introduced **actions**: declarative, *imperative* side-effects you bind to a
resource's lifecycle. This lab covers a classic day-2 need: invalidate a CloudFront cache
automatically whenever the page it serves changes, using the native
`aws_cloudfront_create_invalidation` action instead of a `null_resource` + `local-exec` hack.

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

The event encodes the intent. Here the invalidation publishes a consequence of the change, so it
runs `after_update`: the new object must be in the bucket before the cache is purged. The companion
`terraform-actions-lambda` lab takes the mirror case, a backup that protects against the change, on
`before_update`.

## Why not `local-exec`?

A `null_resource` + `local-exec "aws cloudfront create-invalidation ..."` works, but: it is not in
the plan, it depends on the `aws` CLI and ambient credentials on the runner, its triggering relies
on `triggers` hacks, and errors are opaque. Actions are **first-class**: shown in the plan, run by
the provider with the configured credentials, and bound to real lifecycle events.

## What gets deployed

- A **private** S3 bucket (origin), with public access blocked, versioning and SSE enabled.
- A **CloudFront distribution** (Origin Access Control) serving `index.html` over HTTPS, on the
  managed `Managed-CachingOptimized` policy: default TTL 24 h, so an updated object stays hidden
  behind the cache until it is invalidated.
- The `index.html` object, whose lifecycle triggers the cache invalidation.

## Security baseline

The config aims to pass `trivy config` on the gating findings. Four findings are out of scope for a
teaching demo and are silenced with documented `#trivy:ignore` lines in `main.tf`:

- **WAF** in front of the distribution (`AVD-AWS-0011`).
- **Access logging** to a dedicated log bucket (`AVD-AWS-0010`).
- **Minimum TLS version** (`AVD-AWS-0013`): not settable here, and not for lack of trying. With
  `cloudfront_default_certificate = true`, *"CloudFront automatically sets the security policy to
  `TLSv1` regardless of the value that you set here"*
  ([ViewerCertificate API reference](https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_ViewerCertificate.html)).
  `minimum_protocol_version` only applies to a distribution that serves an alias with its own ACM
  certificate (in `us-east-1`, whatever the distribution's region). `main.tf` carries that
  production shape as a commented block next to `viewer_certificate`.
- **Customer-managed KMS key** for the bucket (`AVD-AWS-0132`): SSE-S3 (AES256) fits public web
  assets behind a CDN, and SSE-KMS would also need a `kms:Decrypt` grant for the OAC.

## Prerequisites

- **Terraform `>= 1.14.0`** (pinned to `1.14.9` via `mise.toml`; actions do not exist before 1.14).
- **AWS provider `6.41.0`** (the `aws_cloudfront_create_invalidation` action ships in the 6.x line).
- AWS credentials for `apply` (`validate`/`plan` need none). Default region: `eu-west-1`.

## Run (live demo)

```bash
terraform init
terraform apply        # creates the bucket + distribution + object;
                       # the after_create event fires the FIRST invalidation.

terraform output cloudfront_url   # open it -> shows "Content version: v1"
```

Then, the day-2 change:

```bash
# Edit content/index.html: change "v1" to "v2".
terraform apply        # the after_update event fires a NEW invalidation;
                       # refresh the URL -> v2 is visible immediately.
```

### Proving the cache was actually purged

`index.html` ships without a `Cache-Control` header, so each edge holds it for the cache policy's
default TTL. `Managed-CachingOptimized` sets that to 24 h (min 1 s, max 1 year, cache key without
cookies, headers or query strings), which is what makes the invalidation necessary: without it, the
updated page stays invisible for up to a day. The `x-cache` and `age` response headers show the
whole cycle:

```bash
URL=$(terraform output -raw cloudfront_url)
curl -sI "$URL" | grep -iE 'x-cache|^age'   # Hit from cloudfront, age climbing -> served from cache
# bump the version in content/index.html, then:
terraform apply
curl -sI "$URL" | grep -iE 'x-cache|^age'   # Miss from cloudfront -> the edge had to refetch
curl -sI "$URL" | grep -iE 'x-cache|^age'   # Hit again, age back to ~0
```

Without the `after_update` trigger, that middle request would still be a `Hit` on the old object.

Invoke the action **stand-alone** (run only the action, no infra change):

```bash
terraform apply -invoke=action.aws_cloudfront_create_invalidation.invalidate
```

Teardown:

```bash
terraform destroy
```

> A CloudFront distribution takes a few minutes to deploy and to tear down, so factor that into
> your run. `terraform validate` (what CI runs) needs no credentials.

## Going further

- `terraform-actions-lambda`: same mechanism with `aws_lambda_invoke` as a generic escape hatch
  when no native provider action fits, and the `before_update` counterpart of the event choice
  discussed above.
