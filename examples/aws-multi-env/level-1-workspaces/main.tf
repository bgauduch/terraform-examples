data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  environment = terraform.workspace

  env_config = {
    dev = {
      vpc_cidr = "10.0.0.0/16"
    }
    prod = {
      vpc_cidr = "10.1.0.0/16"
    }
  }

  config = lookup(local.env_config, local.environment, local.env_config["dev"])

  common_tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = local.config.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project}-${local.environment}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(local.config.vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${var.project}-${local.environment}-public"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(local.config.vpc_cidr, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${var.project}-${local.environment}-private"
    Tier = "private"
  })
}
