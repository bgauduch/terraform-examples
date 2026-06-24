terraform {
  # >= 1.9: cross-variable validation (a condition referencing other var.*).
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
