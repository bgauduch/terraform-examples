terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
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
