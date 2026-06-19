data "aws_caller_identity" "current" {}

locals {
  table_name = var.project

  # Built from known values (not aws_dynamodb_table.this.arn) so the Lambda's IAM
  # policy does not depend on the table. The table's after_create action invokes
  # the Lambda, so a table -> action -> lambda -> table dependency would be a cycle.
  table_arn = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${local.table_name}"

  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Lambda that performs the backup - the generic "do anything" target.
# ---------------------------------------------------------------------------
data "archive_file" "backup" {
  type        = "zip"
  source_file = "${path.module}/lambda/backup.py"
  output_path = "${path.module}/build/backup.zip"
}

resource "aws_cloudwatch_log_group" "backup" {
  name              = "/aws/lambda/${var.project}-backup"
  retention_in_days = 14
  tags              = local.common_tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.project}-backup"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "backup" {
  statement {
    sid       = "CreateTableBackup"
    actions   = ["dynamodb:CreateBackup"]
    resources = [local.table_arn]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.backup.arn}:*"]
  }
}

resource "aws_iam_role_policy" "backup" {
  name   = "${var.project}-backup"
  role   = aws_iam_role.backup.id
  policy = data.aws_iam_policy_document.backup.json
}

resource "aws_lambda_function" "backup" {
  function_name    = "${var.project}-backup"
  role             = aws_iam_role.backup.arn
  runtime          = "python3.12"
  handler          = "backup.handler"
  filename         = data.archive_file.backup.output_path
  source_code_hash = data.archive_file.backup.output_base64sha256
  timeout          = 30

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.backup]
}

# ---------------------------------------------------------------------------
# The action: invoke the Lambda. No native-action equivalent is used on purpose
# - a native `aws_dynamodb_create_backup` action exists, but the lesson here is
# that aws_lambda_invoke lets an action run ANY logic you can put in a function.
# ---------------------------------------------------------------------------
action "aws_lambda_invoke" "backup" {
  config {
    function_name   = aws_lambda_function.backup.function_name
    payload         = jsonencode({ table_name = local.table_name })
    invocation_type = "RequestResponse"
  }
}

# ---------------------------------------------------------------------------
# The table whose lifecycle triggers the backup on create and on update.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "this" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_lambda_invoke.backup]
    }
  }
}
