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

  # Tag de run unique sur chaque ressource : permet à un sweeper de nettoyer
  # les restes si `terraform test` est interrompu avant son auto-destroy (cf sweep.sh).
  default_tags {
    tags = {
      "tftest-suite" = "terraform-module-testing"
      "tftest-run"   = var.run_id
    }
  }
}
