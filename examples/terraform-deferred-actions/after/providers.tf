terraform {
  # Deferred actions (unknown count/for_each) are native from 1.16 onward - no
  # experiments block, no -allow-deferral flag. The alpha is pinned via
  # .terraform-version; prerelease constraints aren't allowed here, so match the
  # 1.16.0 version core (alpha builds satisfy it by their core version).
  required_version = ">= 1.16.0"

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
