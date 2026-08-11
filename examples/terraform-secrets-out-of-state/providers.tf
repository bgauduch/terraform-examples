terraform {
  # Write-only arguments (`<attr>_wo` + `<attr>_wo_version`) are available since
  # Terraform 1.11. `ephemeral` blocks land in 1.10, so write-only sets the floor.
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}
