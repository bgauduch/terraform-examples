# Exemple d'utilisation du module s3-bucket = configuration racine sous test.
module "bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = var.bucket_name
  environment        = var.environment
  enable_encryption  = var.enable_encryption
  kms_key_arn        = var.kms_key_arn
  force_destroy      = var.force_destroy
  versioning_enabled = var.versioning_enabled

  tags = {
    example = "terraform-module-testing"
  }
}
