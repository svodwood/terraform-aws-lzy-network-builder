locals {
  # Load and parse the hub YAML configuration
  hub_config = yamldecode(file(var.hub_definition))

  # Extract hub VPC configuration
  hub_vpc_name   = keys(local.hub_config)[0]
  hub_vpc_config = values(local.hub_config)[0]

  # Prepare VPC config for foundation module
  vpc_config = {
    name                  = local.hub_vpc_name
    cidr                  = local.hub_vpc_config.cidr
    availability_zone_ids = local.hub_vpc_config.availability_zone_ids
    subnets               = try(local.hub_vpc_config.subnets, {})
    account               = var.network_account_id
    type                  = try(local.hub_vpc_config.type, "hub")
    risk                  = try(local.hub_vpc_config.risk, "medium")
    tags                  = try(local.hub_vpc_config.tags, {})
  }

  # Merged tags for VPC
  vpc_tags = merge(var.default_tags, local.vpc_config.tags)

  # Use vpc-foundation module outputs directly for all subnet calculations
  subnet_resources      = module.vpc_foundation.subnet_resources
  vpc_validation_errors = module.vpc_foundation.validation_errors
}

# VPC Foundation Module Integration
# Uses the shared vpc-foundation module for subnet calculations and validation
module "vpc_foundation" {
  source = "../vpc-foundation"

  vpc_config = local.vpc_config

  technical_subnets = {
    relay = {
      suffix     = var.hub_relay_subnet_suffix
      create_for = ["hub"]
      is_shared  = false
      attributes = {
        is_relay = true
      }
    }
    firewall = {
      suffix     = var.hub_firewall_subnet_suffix
      create_for = ["hub"]
      is_shared  = false
      attributes = {
        is_firewall = true
      }
    }
    egress = {
      suffix     = var.hub_egress_subnet_suffix
      create_for = ["hub"]
      is_shared  = false
      attributes = {
        is_egress = true
      }
    }
  }

  module_type = "hub"
}

