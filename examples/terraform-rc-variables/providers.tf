terraform {
  # NOTE: bump to the target Terraform RC before the live to exercise deferred actions.
  # Deferred actions are experimental and enabled at plan time via `-allow-deferral`.
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
