# terraform-check-health

> **Type**: `lab`
> **Tags**: `aws` `check` `drift` `post-apply` `v1.5`

Terraform **1.5** introduced **`check` blocks**: assertions about your **real, deployed**
infrastructure that run on `plan` and `apply` and report failures as **warnings, not errors** -
so they never block your workflow. This lab uses one to verify a live website is healthy and to
**catch out-of-band drift** on the next plan.

## The idea

A `check` block can own a **scoped data source** (re-read every run) and one or more `assert`s:

```hcl
check "website_health" {
  data "http" "home" {
    url = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
  }

  assert {
    condition     = data.http.home.status_code == 200
    error_message = "Website returned HTTP ${data.http.home.status_code}, expected 200."
  }

  assert {
    condition     = strcontains(data.http.home.response_body, "Status: healthy")
    error_message = "Website body is missing the expected marker - content drift."
  }
}
```

## `check` vs `precondition` / `postcondition`

| | When it runs | On failure |
|---|---|---|
| `precondition` / `postcondition` | during a resource's plan/apply | **errors** - blocks the apply |
| `check` | after resources, on every plan/apply | **warns** - never blocks |

Use `check` for continuous health and drift signals you do *not* want to halt a deployment.

## What gets deployed

- A public S3 **static website** (instant, no CDN) serving `content/index.html`.
- One `check` asserting the endpoint returns **200** and serves the expected content.

## Security baseline

A static-website bucket is **public by design**. ACL-based public access stays blocked; the two
policy-related public-access guards are intentionally relaxed and documented with `#trivy:ignore`
lines (`AVD-AWS-0093`, `AVD-AWS-0087`), plus `AVD-AWS-0132` (SSE-S3 is fine for public content).

## Prerequisites

- **Terraform `>= 1.5.0`** (pinned via `mise.toml`; `check` blocks do not exist before 1.5).
- AWS provider `~> 5.0` (contemporary with the 1.5 floor) + `http` provider.
- AWS credentials for `apply` (`validate`/`plan` need none). Default region: `eu-west-1`.

## Run (live demo)

```bash
terraform init
terraform apply        # deploys the site; the check runs and passes (green).
terraform output website_url   # open it -> "Status: healthy"
```

Now simulate **out-of-band drift** and watch the check warn (without blocking):

```bash
# Break the live site behind Terraform's back - replace the object via the AWS CLI:
echo '<h1>tampered</h1>' > /tmp/index.html
aws s3 cp /tmp/index.html "s3://$(terraform output -raw bucket_name)/index.html" --content-type text/html

terraform plan         # the check re-reads the endpoint and emits a WARNING:
                       # "Website body is missing the expected marker - content drift."
```

Remediate by re-applying (Terraform restores the managed object):

```bash
terraform apply        # content back to the managed version; the check passes again.
terraform destroy
```

> `check` failures are **warnings**: `plan`/`apply` still exit 0. That is what makes checks safe
> for continuous drift detection in CI or on a schedule. `terraform validate` (CI) does not execute
> the data source, so it needs no credentials.

## Counter-proof: the same assertion as a gate

`postcondition.tf.disabled` carries the body assertion again, this time as a `postcondition` on a
top-level `data "http"`. Break the site out of band, then compare the two worlds:

```bash
terraform plan; echo $?                              # check alone     -> Warning, exit 0
mv postcondition.tf.disabled postcondition.tf
terraform plan; echo $?                              # + postcondition -> Error,   exit 1
mv postcondition.tf postcondition.tf.disabled
```

Same condition, same data, same failure. One reports, the other refuses.

## References

- [`check` block](https://developer.hashicorp.com/terraform/language/block/check) - syntax, scoped
  data sources, and why failures are warnings.
- [Custom conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions) -
  `precondition` / `postcondition` / `check` side by side, and when to pick which.
- [`terraform validate`](https://developer.hashicorp.com/terraform/language/validate) - why the CI
  gate needs no credentials: it never executes the data source.
- [Health assessments (HCP Terraform)](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/health) -
  continuous validation, i.e. running these checks on a schedule instead of only on plan/apply.
- [`http` data source](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) -
  the probe used here.
- [Hosting a static website on S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html) -
  the website endpoint the check asserts on.
