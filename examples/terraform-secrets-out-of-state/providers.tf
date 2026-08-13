terraform {
  # Write-only arguments (`<attr>_wo` + `<attr>_wo_version`) are available since
  # Terraform 1.11. `ephemeral` blocks land in 1.10, so write-only sets the floor.
  # 1.11.1 rather than 1.11.0: feeding a sensitive+ephemeral value to a write-only
  # argument fails to serialize on 1.11.0 (hashicorp/terraform#36619).
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
