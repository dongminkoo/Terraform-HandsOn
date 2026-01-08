terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = var.aws_region
}

module "network" {
    source = "../../modules/network_3tier"

    name = "tf-prod"

    vpc_cidr = var.vpc_cidr
    azs = var.azs
    public_subnet_cidrs = var.public_subnet_cidrs
    app_subnet_cidrs = var.app_subnet_cidrs
    db_subnet_cidrs = var.db_subnet_cidrs

    tags = {
        Project = "tf"
        Env = "prod"
    }
}