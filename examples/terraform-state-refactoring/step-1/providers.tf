terraform {
  # Feature floors demonstrated in this lab: `moved` 1.1, `import` blocks 1.5,
  # `removed` + destroy=false 1.7.
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}
