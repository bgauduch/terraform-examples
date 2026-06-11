module "network" {
  source = "../modules/network"

  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
  project     = "demo-tf-multi-env"
  region      = var.region
}
