terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.10.0"
    }
  }
}

locals {
  network_account_profile = "network-account"
  hub_definition          = "../hub/us-east-1.yaml"
  spokes_definition       = "../spokes/us-east-1.yaml"
}

provider "aws" {
  profile = local.network_account_profile
  region  = split(".", basename(local.hub_definition))[0]
}

module "lzy_network_builder" {
  source = "svodwood/lzy-network-builder/aws"

  network_account_id      = "123456789101"
  network_account_profile = local.network_account_profile

  hub_definition    = local.hub_definition
  spokes_definition = local.spokes_definition

  firewall_type = "aws_network_firewall"
  
  default_tags = {
    ManagedBy = "LZYNetworkBuilder"
  }
}
