terraform {
  # `moved` blocks (shipped by later versions of this module) land in Terraform 1.1.
  required_version = ">= 1.1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
