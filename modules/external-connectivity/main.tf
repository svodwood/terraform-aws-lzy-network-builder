locals {
  # External connectivity VPC configuration
  vpc_config = {
    name                  = "external-connectivity"
    cidr                  = var.external_connectivity_cidr
    type                  = "external-connectivity"
    risk                  = "medium"
    availability_zone_ids = var.availability_zone_ids
    subnets               = {}
    account               = var.network_account_id
    tags = {
      Name = "external-connectivity"
    }
  }

  # Use vpc-foundation module outputs directly for all subnet calculations
  subnet_resources      = module.vpc_foundation.subnet_resources
  vpc_validation_errors = module.vpc_foundation.validation_errors

  # External connectivity VPC data
  vpc_data = {
    account               = local.vpc_config.account
    cidr                  = local.vpc_config.cidr
    type                  = local.vpc_config.type
    availability_zone_ids = local.vpc_config.availability_zone_ids
    tags                  = merge(var.default_tags, local.vpc_config.tags)
  }

  # Process VPC endpoints configuration
  interface_endpoints = {
    for endpoint_name, endpoint_config in var.vpc_endpoints_config : endpoint_name => {
      vpc_name          = "external-connectivity"
      vpc_id            = aws_vpc.external_connectivity.id
      service_name      = endpoint_name
      subnet_ids        = [for subnet_key, subnet in local.subnet_resources : aws_subnet.external_connectivity[subnet_key].id if subnet.is_shared_endpoints]
      security_group_id = aws_security_group.vpc_endpoints.id
      policy            = try(endpoint_config.policy, null)
      vpc_tags          = local.vpc_config.tags
    }
  }
}

# VPC Foundation Module Integration
# Uses the shared vpc-foundation module for subnet calculations and validation
module "vpc_foundation" {
  source = "../vpc-foundation"

  vpc_config = local.vpc_config

  technical_subnets = {
    relay = {
      suffix     = var.relay_subnet_suffix
      create_for = ["external-connectivity"]
      is_shared  = false
      attributes = {
        is_relay = true
      }
    }
    endpoints = {
      suffix     = var.endpoints_subnet_suffix
      create_for = ["external-connectivity"]
      is_shared  = false
      attributes = {
        is_shared_endpoints = true
      }
    }
  }

  module_type = "generic"
}
