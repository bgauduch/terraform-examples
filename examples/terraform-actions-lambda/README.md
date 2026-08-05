# terraform-actions-lambda

> **Type**: `lab`
> **Tags**: `aws` `actions` `lambda` `dynamodb` `v1.14`

Terraform **1.14** actions can run **provider-native** side-effects (see `terraform-actions` for a
CloudFront invalidation). But the provider only ships a handful of native actions. This lab shows
the **escape hatch**: `action "aws_lambda_invoke"` lets a lifecycle event run **any logic you can
put in a Lambda**. The illustration: take a **timestamped on-demand DynamoDB backup** before
Terraform ever mutates the table.

> **Day 0 / day 1 / day 2**, since the whole point hangs on it: day 0 is design, day 1 is build and
> deploy, day 2 is everything after go-live (operate, evolve, repair). In Terraform terms, day 1
> creates the resource and day 2 is the work that keeps happening to it afterwards.

## The idea

```hcl
action "aws_lambda_invoke" "backup" {
  config {
    function_name   = aws_lambda_function.backup.function_name
    payload         = jsonencode({ table_name = local.table_name })
    invocation_type = "RequestResponse"
  }
}

resource "aws_dynamodb_table" "this" {
  # ...
  lifecycle {
    action_trigger {
      events  = [after_create, before_update]
      actions = [action.aws_lambda_invoke.backup]
    }
  }
}
```

The Lambda (`lambda/backup.py`) calls `dynamodb.create_backup(...)`, but it could run anything
else: a third-party API call, a Slack post, a data migration. That is the point.

## Why `before_update` and not `after_update`

The event you pick encodes the intent. `after_*` publishes a consequence of the change (the
companion `terraform-actions` lab invalidates a CDN cache *after* new content is uploaded).
`before_update` protects against the change: the snapshot is taken while the table is still in its
previous state, so an unwanted schema or capacity change is recoverable. In the apply output the
action completes **before** `Modifying...` on the table.

`after_create` still fires once, on creation: there is nothing to back up before a table exists.

> A native `aws_dynamodb_create_backup` action exists. Going through Lambda here demonstrates the
> generic mechanism. Reach for a native action first when one fits.

The backup is the illustration because it reads in one screen and its effect is checkable with one
CLI call. The escape hatch earns its keep on the day-2 work no provider action covers, the kind that
used to sit in a `null_resource` + `local-exec` or in a pipeline step bolted next to Terraform:

- purge a CDN or WAF you do not host (Cloudflare, Fastly, Akamai),
- seed reference data, or backfill an attribute after a schema change,
- register a release or a deployment marker in a third-party system,
- call an internal API to drain a component before it gets replaced.

Same wiring as below, only the Lambda body changes.

## Why PITR stays on next to the action's snapshots

They answer different questions. PITR restores to any second in a rolling window, for the incident
nobody planned. The action's snapshot is deliberate and named, taken right before a schema change
and addressable in a rollback procedure six months later. Dropping PITR would also trade a clean
scanner run for an `AVD-AWS-0024` ignore.

## Avoiding the dependency cycle

The table's `after_create` action invokes the Lambda, so the Lambda must **not** depend on the
table (that would be `table → action → lambda → table`). The Lambda's IAM policy therefore scopes
`dynamodb:CreateBackup` to an ARN built from `var.region` + the caller account id + the table name
(`local.table_arn`), not from `aws_dynamodb_table.this.arn`.

## What gets deployed

- A DynamoDB table (`PAY_PER_REQUEST`, point-in-time recovery + SSE enabled).
- A Python Lambda + least-privilege IAM role (`dynamodb:CreateBackup` on the table, write to its own
  log group) and an explicit CloudWatch log group with retention.

## Prerequisites

- **Terraform `>= 1.14.0`** (pinned to `1.14.9` via `mise.toml`; actions do not exist before 1.14).
- **AWS provider `6.41.0`** (carries the `aws_lambda_invoke` action).
- AWS credentials for `apply` (`validate`/`plan` need none). Default region: `eu-west-1`.

## Run (live demo)

```bash
terraform init
terraform apply        # creates the table + Lambda; after_create fires the FIRST backup.

# See the backup the action just created:
aws dynamodb list-backups --table-name "$(terraform output -raw table_name)" --region eu-west-1
```

Then, the day-2 change:

```bash
# Uncomment the `ttl` block on aws_dynamodb_table.this in main.tf, then:
terraform apply        # before_update fires a NEW timestamped backup, then the table is modified.
```

Pick a fast mutation to demo this: enabling TTL or changing tags settles in ~5 s, while adding a
global secondary index takes several minutes of `Still modifying...`.

TTL is rate-limited. `UpdateTimeToLive` takes up to an hour to fully process, and any further call on
the same table inside that window fails with a `ValidationException`
([API reference](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_UpdateTimeToLive.html)).
Running the gesture twice in a row means waiting out the hour, or switching to a tag change.

Invoke the action **stand-alone** (back up on demand, no infra change):

```bash
terraform apply -invoke=action.aws_lambda_invoke.backup
```

Teardown, in one command:

```bash
mise run teardown      # sweep.sh --force, then terraform destroy
```

Or step by step, to see what is left behind:

```bash
./sweep.sh             # lists the on-demand backups (dry-run)
./sweep.sh --force     # deletes them
terraform destroy      # removes the table, the Lambda, the role and the log group
```

Sweeping first is only a preference: the sweeper targets the table by name (`TABLE_NAME`, defaulting
to the `project` value) rather than through the state, so either order works.

**`terraform destroy` does not delete the backups.** They outlive the table by design and the Lambda
creates them out of band, so they never reach the state. Destroy-time `action_trigger` events, which
would let the lab clean up after itself, are Terraform 1.16 (alpha), hence the sweeper.

PITR adds one residue you cannot sweep: deleting the table leaves a `<table>$DeletedTableBackup`
system backup, kept 35 days at no cost and refused by `delete-backup`
([PITR reference](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery_Howitworks.html)).
`sweep.sh` lists it rather than hiding it, since `list-backups` filters on `USER` by default.

## Going further

- `terraform-actions`: the same mechanism with a native provider action (CloudFront), and the
  `after_update` counterpart of the event choice discussed above.

## Troubleshooting

- `dial tcp 0.0.0.0:443: connect: connection refused` on `logs.<region>.amazonaws.com`: a local
  DNS filter (Pi-hole, AdGuard, router-level ad blocking) is blackholing hostnames that start with
  `logs.`, so the log group resource fails on create and even on refresh. Point the SDK at the
  dual-stack endpoint, which resolves normally, in the shell that runs Terraform:

  ```bash
  export AWS_ENDPOINT_URL_CLOUDWATCH_LOGS=https://logs.eu-west-1.api.aws
  ```

  `AWS_ENDPOINT_URL_<SERVICE>` is the standard per-service override, where `<SERVICE>` is the API
  model `serviceId` uppercased with spaces turned into underscores
  ([SDK reference](https://docs.aws.amazon.com/sdkref/latest/guide/feature-ss-endpoints.html)). It
  keeps the fix inside the repo instead of depending on the network you happen to sit behind.
  Allow-listing the endpoint on the resolver works too, when you own it.

## References

- [`action` block](https://developer.hashicorp.com/terraform/language/block/action) - `action` and
  `action_trigger` syntax, and the lifecycle events they bind to.
- [Lambda invocation modes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-invocation.html) -
  sync versus async, and why the choice changes what Terraform observes.
- [DynamoDB on-demand backup](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/OnDemandBackup.html) -
  the operation the function performs.
