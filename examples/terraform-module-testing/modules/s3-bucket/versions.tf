terraform {
  # >= 1.9 : validation croisée entre variables (condition référençant d'autres var.*).
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
