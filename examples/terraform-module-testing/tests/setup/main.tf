# Test helper module: produces a random suffix for globally unique bucket
# names (S3). No credential required (random provider).
terraform {
  required_version = "~> 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

output "suffix" {
  value = random_id.suffix.hex
}
