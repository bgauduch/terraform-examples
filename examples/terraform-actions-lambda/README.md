# terraform-actions-lambda

> **Type**: `lab` &nbsp;·&nbsp; **Tags**: `aws` `actions` `lambda` `dynamodb` `v1.14`

Terraform **1.14** actions can run **provider-native** side-effects (see `terraform-actions` for a
CloudFront invalidation). But the provider only ships a handful of native actions. This lab shows
the **escape hatch**: `action "aws_lambda_invoke"` lets a lifecycle event run **any logic you can
put in a Lambda**. The illustration: take a **timestamped on-demand DynamoDB backup** whenever the
table is created or updated.

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
      events  = [after_create, after_update]
      actions = [action.aws_lambda_invoke.backup]
    }
  }
}
```

The Lambda (`lambda/backup.py`) just calls `dynamodb.create_backup(...)` - but it could do
*anything*: call a third-party API, post to Slack, run a data migration. That is the point.

> A native `aws_dynamodb_create_backup` action actually exists. We deliberately go through Lambda
> here to demonstrate the generic mechanism - reach for a native action first when one fits.

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

- **Terraform `>= 1.14.0`** (pinned via `.terraform-version`; actions do not exist before 1.14).
- **AWS provider `6.41.0`** (carries the `aws_lambda_invoke` action).
- AWS credentials for `apply` (`validate`/`plan` need none). Default region: `eu-west-1`.

## Run (live demo)

```bash
terraform init
terraform apply        # creates the table + Lambda; after_create fires the FIRST backup.

# See the backup the action just created:
aws dynamodb list-backups --table-name "$(terraform output -raw table_name)" --region eu-west-1
```

Then, live:

```bash
# Change a table attribute (e.g. add/raise a tag) and re-apply:
terraform apply        # after_update fires a NEW timestamped backup.
```

Invoke the action **stand-alone** (back up on demand, no infra change):

```bash
terraform apply -invoke=action.aws_lambda_invoke.backup
```

Teardown:

```bash
terraform destroy      # on-demand backups survive table deletion - remove them manually if needed.
```

## Going further

- `terraform-actions` - the same mechanism with a **native** provider action (CloudFront).
