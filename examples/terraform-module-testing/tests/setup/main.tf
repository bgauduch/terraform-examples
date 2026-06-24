# Module helper de test : produit un suffixe aléatoire pour des noms de bucket
# globalement uniques (S3). Aucun credential requis (provider random).
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
