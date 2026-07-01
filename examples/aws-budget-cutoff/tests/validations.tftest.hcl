# Creds-free layer: input variable validations only (expect_failures).
# The SCP / budget action / org resources need a real management account, so they are
# covered by `terraform validate` + a real apply the evening before the demo, not here.
#
# mock_provider keeps this suite offline: no SSO, no AWS calls - only the input-variable
# validations are exercised.

# Give the mocked aws_iam_policy_document a valid JSON default so IAM resources plan cleanly
# (the aws provider validates assume_role_policy is a JSON object at plan time).
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "aws" {
  alias = "sandbox"
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  mgmt_profile       = "mgmt"
  sandbox_profile    = "sandbox"
  mgmt_account_id    = "111111111111"
  sandbox_account_id = "222222222222"
  notify_email       = "ops@example.com"
}

run "rejects_short_sandbox_account_id" {
  command = plan
  variables {
    sandbox_account_id = "123"
  }
  expect_failures = [var.sandbox_account_id]
}

run "rejects_non_numeric_mgmt_account_id" {
  command = plan
  variables {
    mgmt_account_id = "not-an-account"
  }
  expect_failures = [var.mgmt_account_id]
}

run "rejects_bad_email" {
  command = plan
  variables {
    notify_email = "nope"
  }
  expect_failures = [var.notify_email]
}
