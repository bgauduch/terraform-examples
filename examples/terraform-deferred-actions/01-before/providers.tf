terraform {
  # The pre-1.16 world: count/for_each cannot depend on values unknown at plan,
  # which is exactly why the module needs a separate, plan-known `provided` flag.
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}
