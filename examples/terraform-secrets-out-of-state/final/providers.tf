terraform {
  # Write-only arguments require Terraform 1.11 or later. 1.11.1 rather than
  # 1.11.0: a sensitive+ephemeral value fed to a write-only argument fails to
  # serialize on 1.11.0 (hashicorp/terraform#36619).
  required_version = ">= 1.11.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}
