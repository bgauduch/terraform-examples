# Sandbox account: the OPTIONAL full-auto remediation layer. It sits OFF the critical path -
# the cut-off (SCP attach) works without any of this. Here we clean up + notify.
#
# Demo trigger: direct `aws lambda invoke` on stage.
# Prod trigger (documented, not built to keep the lab account-local): an EventBridge rule on
# the Organizations AttachPolicy CloudTrail event (management account, us-east-1) -> invoke
# this Lambda cross-account. See README "Full-auto wiring".

# Customer-managed key encrypting the notification topic at rest.
resource "aws_kms_key" "notify" {
  provider    = aws.sandbox
  description = "CMK for the cut-off remediation SNS topic"
  # AWS-0065: annual rotation of the key material (security baseline).
  enable_key_rotation = true
  # AWS minimum; short here so the demo tears down quickly.
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "notify" {
  provider      = aws.sandbox
  name          = "alias/cutoff-notify"
  target_key_id = aws_kms_key.notify.key_id
}

# Notification channel + the human "retour". SSE with the CMK above.
resource "aws_sns_topic" "notify" {
  provider          = aws.sandbox
  name              = "cutoff-notify"
  kms_master_key_id = aws_kms_key.notify.key_id
}

resource "aws_sns_topic_subscription" "notify_email" {
  provider  = aws.sandbox
  topic_arn = aws_sns_topic.notify.arn
  protocol  = "email"
  endpoint  = var.notify_email
}

data "archive_file" "remediation" {
  type        = "zip"
  source_file = "${path.module}/lambda/remediation.py"
  output_path = "${path.module}/.build/remediation.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  provider = aws.sandbox
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "remediation" {
  provider           = aws.sandbox
  name               = "cutoff-remediation"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "remediation" {
  provider = aws.sandbox

  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:${var.sandbox_account_id}:*"]
  }

  statement {
    sid       = "FindAndTerminateRunaway"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances", "ec2:TerminateInstances"]
    resources = ["*"]
  }

  statement {
    sid       = "Notify"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.notify.arn]
  }

  # Publishing to the SSE-encrypted topic needs to use the CMK.
  statement {
    sid       = "UseNotifyKey"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [aws_kms_key.notify.arn]
  }
}

resource "aws_iam_role_policy" "remediation" {
  provider = aws.sandbox
  name     = "cutoff-remediation"
  role     = aws_iam_role.remediation.id
  policy   = data.aws_iam_policy_document.remediation.json
}

resource "aws_lambda_function" "remediation" {
  provider         = aws.sandbox
  function_name    = "cutoff-remediation"
  role             = aws_iam_role.remediation.arn
  handler          = "remediation.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.remediation.output_path
  source_code_hash = data.archive_file.remediation.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      RUNAWAY_TAG_KEY   = "demo"
      RUNAWAY_TAG_VALUE = "runaway"
      NOTIFY_TOPIC_ARN  = aws_sns_topic.notify.arn
    }
  }
}
