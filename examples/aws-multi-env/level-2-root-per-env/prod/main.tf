module "network" {
  source = "../modules/network"

  environment = "prod"
  vpc_cidr    = "10.1.0.0/16"
  project     = "demo-tf-multi-env"
  region      = var.region
}
