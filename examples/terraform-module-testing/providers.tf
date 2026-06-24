terraform {
  # Root module: pin with ~> (lower + upper bound) to avoid accidental upgrades to an
  # untested major. Reusable child modules use >= instead (see modules/s3-bucket/versions.tf).
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Unique run tag on every resource: lets a sweeper clean up leftovers if
  # `terraform test` is interrupted before its auto-destroy (see sweep.sh).
  default_tags {
    tags = {
      "tftest-suite" = "terraform-module-testing"
      "tftest-run"   = var.run_id
    }
  }
}
