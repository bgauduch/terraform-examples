terraform {
  # Root module: pin with ~> (lower + upper bound) to avoid an accidental jump to an
  # untested major.
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Management (payer) account: AWS Organizations SCPs + AWS Budgets live here.
# Budget Actions of type APPLY_SCP_POLICY can only be created from the org management
# (or a delegated admin) account.
provider "aws" {
  region  = var.region
  profile = var.mgmt_profile

  default_tags {
    tags = {
      example = "aws-budget-cutoff"
      scope   = "management"
    }
  }
}

# Sandbox member account: the "runaway" resource + the remediation stack live here.
# Region-locked to eu-west-1 by a pre-existing sandbox SCP.
provider "aws" {
  alias   = "sandbox"
  region  = var.region
  profile = var.sandbox_profile

  default_tags {
    tags = {
      example = "aws-budget-cutoff"
      scope   = "sandbox"
    }
  }
}
