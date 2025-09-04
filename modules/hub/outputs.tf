output "vpc" {
  description = "Hub VPC configuration and ID"
  value = {
    id                    = aws_vpc.hub_vpc.id
    cidr_block            = aws_vpc.hub_vpc.cidr_block
    account               = var.network_account_id
    availability_zone_ids = local.hub_vpc_config.availability_zone_ids
    vpc_name              = local.hub_vpc_name
    tags                  = aws_vpc.hub_vpc.tags
  }
}

output "subnets" {
  description = "Map of hub subnet configurations and IDs"
  value = {
    for subnet_key, subnet in aws_subnet.hub : subnet_key => {
      id                   = subnet.id
      cidr_block           = subnet.cidr_block
      vpc_id               = subnet.vpc_id
      vpc_name             = local.subnet_resources[subnet_key].vpc_name
      subnet_name          = local.subnet_resources[subnet_key].subnet_name
      availability_zone_id = local.subnet_resources[subnet_key].availability_zone_id
      account              = local.subnet_resources[subnet_key].account
      is_firewall          = local.subnet_resources[subnet_key].is_firewall
      is_egress            = local.subnet_resources[subnet_key].is_egress
      is_relay             = local.subnet_resources[subnet_key].is_relay
      is_shared_endpoints  = local.subnet_resources[subnet_key].is_shared_endpoints
      tags                 = subnet.tags
    }
  }
}

output "subnet_allocation_debug" {
  description = "Hub subnet allocation details for debugging (from vpc-foundation module)"
  value       = module.vpc_foundation.vpc_space_calculation
}

output "validation_errors" {
  description = "Hub VPC validation errors"
  value       = local.vpc_validation_errors
}

output "route_tables" {
  description = "Route tables for hub subnets"
  value = {
    for subnet_key, rt in aws_route_table.hub_subnet_routes : subnet_key => {
      id                   = rt.id
      vpc_id               = rt.vpc_id
      subnet_id            = aws_subnet.hub[subnet_key].id
      vpc_name             = local.subnet_resources[subnet_key].vpc_name
      subnet_name          = local.subnet_resources[subnet_key].subnet_name
      availability_zone_id = local.subnet_resources[subnet_key].availability_zone_id
      tags                 = rt.tags
    }
  }
}

output "spoke_connectivity_transit_gateway" {
  description = "Transit Gateway for spoke connectivity"
  value = {
    id                                 = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.id
    arn                                = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.arn
    association_default_route_table_id = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.association_default_route_table_id
    propagation_default_route_table_id = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.propagation_default_route_table_id
    vpc_name                           = local.hub_vpc_name
    tags                               = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.tags
  }
}

output "spoke_connectivity_transit_gateway_attachments" {
  description = "Transit Gateway VPC attachments for configured subnet type"
  value = {
    (local.hub_vpc_name) = {
      id                 = aws_ec2_transit_gateway_vpc_attachment.spoke_connectivity_tgw_attachment.id
      transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.spoke_connectivity_tgw_attachment.transit_gateway_id
      vpc_id             = aws_ec2_transit_gateway_vpc_attachment.spoke_connectivity_tgw_attachment.vpc_id
      subnet_ids         = aws_ec2_transit_gateway_vpc_attachment.spoke_connectivity_tgw_attachment.subnet_ids
      vpc_name           = local.hub_vpc_name
      subnet_type        = "relay"
      availability_zones = [
        for subnet_key, subnet_config in local.subnet_resources :
        subnet_config.availability_zone_id
        if subnet_config.vpc_name == local.hub_vpc_name && subnet_config.is_relay
      ]
      tags = aws_ec2_transit_gateway_vpc_attachment.spoke_connectivity_tgw_attachment.tags
    }
  }
}

output "relay_route_tables" {
  description = "Route tables for relay subnets (for firewall routing)"
  value = {
    for subnet_key, rt in aws_route_table.hub_subnet_routes : subnet_key => {
      id                   = rt.id
      vpc_name             = local.subnet_resources[subnet_key].vpc_name
      availability_zone_id = local.subnet_resources[subnet_key].availability_zone_id
    }
    if local.subnet_resources[subnet_key].is_relay
  }
}

output "egress_route_tables" {
  description = "Route tables for egress subnets (for firewall routing)"
  value = {
    for subnet_key, rt in aws_route_table.hub_subnet_routes : subnet_key => {
      id                   = rt.id
      vpc_name             = local.subnet_resources[subnet_key].vpc_name
      availability_zone_id = local.subnet_resources[subnet_key].availability_zone_id
    }
    if local.subnet_resources[subnet_key].is_egress
  }
}

output "spoke_connectivity_transit_gateway_firewall_route_tables" {
  description = "Transit Gateway route tables for firewall inspection (hub)"
  value = {
    (local.hub_vpc_name) = {
      id                 = aws_ec2_transit_gateway_route_table.firewall_route_table.id
      transit_gateway_id = aws_ec2_transit_gateway_route_table.firewall_route_table.transit_gateway_id
      vpc_name           = local.hub_vpc_name
      tags               = aws_ec2_transit_gateway_route_table.firewall_route_table.tags
    }
  }
}

output "vpc_endpoints_config" {
  description = "VPC endpoints configuration from YAML for external connectivity module"
  value       = try(local.hub_vpc_config.vpc_endpoints, {})
}

output "hub_internal_transit_gateway" {
  description = "Hub Internal Transit Gateway for user-defined subnets to shared endpoints"
  value = {
    id                                 = aws_ec2_transit_gateway.hub_internal_transit_gateway.id
    arn                                = aws_ec2_transit_gateway.hub_internal_transit_gateway.arn
    association_default_route_table_id = aws_ec2_transit_gateway.hub_internal_transit_gateway.association_default_route_table_id
    propagation_default_route_table_id = aws_ec2_transit_gateway.hub_internal_transit_gateway.propagation_default_route_table_id
    vpc_name                           = local.hub_vpc_name
    tags                               = aws_ec2_transit_gateway.hub_internal_transit_gateway.tags
  }
}

output "hub_internal_transit_gateway_attachment" {
  description = "Hub Internal Transit Gateway VPC attachment"
  value = {
    id                 = aws_ec2_transit_gateway_vpc_attachment.hub_internal_tgw_attachment.id
    transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.hub_internal_tgw_attachment.transit_gateway_id
    vpc_id             = aws_ec2_transit_gateway_vpc_attachment.hub_internal_tgw_attachment.vpc_id
    subnet_ids         = aws_ec2_transit_gateway_vpc_attachment.hub_internal_tgw_attachment.subnet_ids
    vpc_name           = local.hub_vpc_name
    subnet_type        = "relay"
    availability_zones = [
      for subnet_key, subnet_config in local.subnet_resources :
      subnet_config.availability_zone_id
      if subnet_config.vpc_name == local.hub_vpc_name && subnet_config.is_relay
    ]
    tags = aws_ec2_transit_gateway_vpc_attachment.hub_internal_tgw_attachment.tags
  }
}

output "hub_internal_transit_gateway_route_table" {
  description = "Hub Internal Transit Gateway route table for user-defined subnets"
  value = {
    id                 = aws_ec2_transit_gateway_route_table.hub_internal_route_table.id
    transit_gateway_id = aws_ec2_transit_gateway_route_table.hub_internal_route_table.transit_gateway_id
    vpc_name           = local.hub_vpc_name
    tags               = aws_ec2_transit_gateway_route_table.hub_internal_route_table.tags
  }
}

output "user_defined_subnet_cidrs" {
  description = "CIDR blocks of user-defined subnets for Internal Hub TGW routing"
  value = [
    for subnet_key, subnet_config in local.subnet_resources :
    subnet_config.cidr_block
    if subnet_config.vpc_name == local.hub_vpc_name && subnet_config.is_user
  ]
}
