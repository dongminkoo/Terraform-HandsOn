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

    name = "tf-dev"
    cluster_name = var.cluster_name

    vpc_cidr = var.vpc_cidr
    azs = var.azs
    public_subnet_cidrs = var.public_subnet_cidrs
    app_subnet_cidrs = var.app_subnet_cidrs
    db_subnet_cidrs = var.db_subnet_cidrs

    tags = {
        Project = "tf"
        Env = "dev"
    }
}

module "eks" {
    source = "../../modules/eks"

    cluster_name = var.cluster_name
    vpc_id = module.network.vpc_id
    subnet_ids = module.network.app_subnet_ids

    tags = {
        Project = "tf"
        Env = "dev"
    }
}

