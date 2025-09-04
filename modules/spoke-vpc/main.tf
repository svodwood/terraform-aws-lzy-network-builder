locals {
  # Base technical subnets that apply to this VPC
  base_technical_subnets = {
    relay = {
      suffix     = var.spoke_relay_subnet_suffix
      create_for = ["all"]
      is_shared  = false
      attributes = { is_relay = true }
    }
    inspection = {
      suffix = var.spoke_inspection_subnet_suffix
      create_for = concat(
        ["public"],
        var.vpc_config.risk == "high" ? [var.vpc_name] : []
      )
      is_shared  = false
      attributes = { is_inspection = true }
    }
  }

  # Public endpoints subnet for public VPCs
  public_endpoints_subnet = var.vpc_config.type == "public" && var.vpc_config.public_endpoints_size != null ? {
    pub-endpoints = {
      suffix     = var.vpc_config.public_endpoints_size
      create_for = ["public"]
      is_shared  = true
      attributes = { is_public_endpoints = true }
    }
  } : {}

  # Combined technical subnets
  technical_subnets = merge(local.base_technical_subnets, local.public_endpoints_subnet)

  # Prepare VPC config for foundation module
  vpc_config = {
    name                  = var.vpc_name
    cidr                  = var.vpc_config.cidr
    type                  = var.vpc_config.type
    risk                  = var.vpc_config.risk
    availability_zone_ids = var.vpc_config.availability_zone_ids
    subnets               = var.vpc_config.subnets
    account               = var.vpc_config.account
    tags                  = var.vpc_config.tags
    public_endpoints_size = var.vpc_config.public_endpoints_size
  }

  # Merged tags for VPC
  vpc_tags = merge(var.default_tags, var.vpc_config.tags)
}

# Foundation module for subnet calculations
module "foundation" {
  source = "../vpc-foundation"

  vpc_config        = local.vpc_config
  technical_subnets = local.technical_subnets
  module_type       = "spoke"
}
