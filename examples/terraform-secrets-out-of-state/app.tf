# ---------------------------------------------------------------------------
# The invariant half of this lab. Nothing here changes across the six steps.
#
# The consumer reads the secret by ARN at runtime. Terraform wires the ARN and
# the IAM permission, never the value - which is exactly why the write path can
# change six times without the consumer noticing.
# ---------------------------------------------------------------------------

locals {
  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

# A customer-managed key rather than the AWS-managed default: the point of this
# lab is that the vault is the one place the value legitimately rests, so that
# place gets a key whose policy and rotation you own.
resource "aws_kms_key" "secrets" {
  description             = "Encrypts the ${var.project} lab secret."
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = local.common_tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project}"
  target_key_id = aws_kms_key.secrets.key_id
}

# recovery_window_in_days = 0 so `destroy` frees the name immediately. The default
# 7-day recovery window keeps the name reserved and breaks the destroy/re-apply
# loop this lab depends on.
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.project}/api-token"
  description             = "Throwaway credential set for the secrets-out-of-state lab."
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 0

  tags = local.common_tags
}

data "archive_file" "fingerprint" {
  type        = "zip"
  source_file = "${path.module}/lambda/fingerprint.py"
  output_path = "${path.module}/build/fingerprint.zip"
}

# Encrypting this log group with the secret's CMK would mean granting the CloudWatch
# Logs service principal use of a key whose only job is protecting the secret. The
# function logs a fingerprint and never the value, so widening that key policy would
# trade a real boundary for a clean report. Documented, not hidden.
#trivy:ignore:AVD-AWS-0017
resource "aws_cloudwatch_log_group" "fingerprint" {
  name              = "/aws/lambda/${var.project}-fingerprint"
  retention_in_days = 14

  tags = local.common_tags
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

# The permission is scoped to this one secret ARN. The consumer can read the
# current value and nothing else - no wildcard, no blanket secretsmanager:*.
data "aws_iam_policy_document" "read_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.app.arn]
  }

  # Reading a secret encrypted with a CMK requires decrypting its data key.
  statement {
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.secrets.arn]
  }

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.fingerprint.arn}:*"]
  }
}

resource "aws_iam_role" "fingerprint" {
  name               = "${var.project}-fingerprint"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "fingerprint" {
  name   = "read-secret"
  role   = aws_iam_role.fingerprint.id
  policy = data.aws_iam_policy_document.read_secret.json
}

#trivy:ignore:AVD-AWS-0066 X-Ray tracing adds noise to a 30-second teaching demo.
resource "aws_lambda_function" "fingerprint" {
  function_name    = "${var.project}-fingerprint"
  role             = aws_iam_role.fingerprint.arn
  runtime          = "python3.12"
  handler          = "fingerprint.handler"
  filename         = data.archive_file.fingerprint.output_path
  source_code_hash = data.archive_file.fingerprint.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      # The ARN, never the value. This is the whole point of the lab.
      SECRET_ARN = aws_secretsmanager_secret.app.arn

      # `stdout` returns the fingerprint. `twitch` also posts it to a chat, which
      # only proves the same thing out loud - the demo never depends on it.
      SINK           = var.sink
      TWITCH_USER_ID = var.twitch_user_id
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.fingerprint]
}
