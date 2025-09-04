output "vpc" {
  description = "External connectivity VPC details"
  value = {
    id                    = aws_vpc.external_connectivity.id
    arn                   = aws_vpc.external_connectivity.arn
    cidr_block            = aws_vpc.external_connectivity.cidr_block
    vpc_name              = "external-connectivity"
    availability_zone_ids = local.vpc_data.availability_zone_ids
    tags                  = aws_vpc.external_connectivity.tags
  }
}

output "subnets" {
  description = "Map of external connectivity subnets"
  value = {
    for subnet_key, subnet_config in local.subnet_resources :
    subnet_key => {
      id                   = aws_subnet.external_connectivity[subnet_key].id
      arn                  = aws_subnet.external_connectivity[subnet_key].arn
      cidr_block           = aws_subnet.external_connectivity[subnet_key].cidr_block
      subnet_name          = subnet_config.subnet_name
      vpc_name             = subnet_config.vpc_name
      availability_zone_id = subnet_config.availability_zone_id
      account              = subnet_config.account
      type                 = subnet_config.type
      risk                 = subnet_config.risk
      is_relay             = try(subnet_config.is_relay, false)
      is_shared_endpoints  = try(subnet_config.is_shared_endpoints, false)
      tags                 = aws_subnet.external_connectivity[subnet_key].tags
    }
  }
}

output "subnet_route_tables" {
  description = "Map of subnet route tables"
  value = {
    for subnet_key, _ in local.subnet_resources :
    subnet_key => {
      id   = aws_route_table.external_connectivity_subnet_routes[subnet_key].id
      arn  = aws_route_table.external_connectivity_subnet_routes[subnet_key].arn
      tags = aws_route_table.external_connectivity_subnet_routes[subnet_key].tags
    }
  }
}

output "endpoints_route_tables" {
  description = "Route tables for endpoints subnets"
  value = {
    for subnet_key, rt in aws_route_table.external_connectivity_subnet_routes : subnet_key => {
      id                   = rt.id
      vpc_name             = local.subnet_resources[subnet_key].vpc_name
      availability_zone_id = local.subnet_resources[subnet_key].availability_zone_id
    }
    if local.subnet_resources[subnet_key].is_shared_endpoints
  }
}

output "relay_route_tables" {
  description = "Route tables for relay subnets"
  value = {
    for subnet_key, rt in aws_route_table.external_connectivity_subnet_routes : subnet_key => {
      id                   = rt.id
      vpc_name             = local.subnet_resources[subnet_key].vpc_name
      availability_zone_id = local.subnet_resources[subnet_key].availability_zone_id
    }
    if local.subnet_resources[subnet_key].is_relay
  }
}

output "transit_gateway_attachment" {
  description = "Transit Gateway VPC attachment for external connectivity"
  value = {
    id                 = aws_ec2_transit_gateway_vpc_attachment.external_connectivity.id
    transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.external_connectivity.transit_gateway_id
    vpc_id             = aws_ec2_transit_gateway_vpc_attachment.external_connectivity.vpc_id
    subnet_ids         = aws_ec2_transit_gateway_vpc_attachment.external_connectivity.subnet_ids
    subnet_type        = "relay"
    availability_zones = [
      for subnet_key, subnet_config in local.subnet_resources :
      subnet_config.availability_zone_id
      if subnet_config.is_relay
    ]
    tags     = aws_ec2_transit_gateway_vpc_attachment.external_connectivity.tags
    vpc_name = "external-connectivity"
  }
}

output "transit_gateway_route_table" {
  description = "Transit Gateway route table for external connectivity VPC"
  value = {
    id   = aws_ec2_transit_gateway_route_table.external_connectivity_route_table.id
    arn  = aws_ec2_transit_gateway_route_table.external_connectivity_route_table.arn
    tags = aws_ec2_transit_gateway_route_table.external_connectivity_route_table.tags
  }
}

output "vpc_endpoints" {
  description = "Map of VPC interface endpoints"
  value = {
    for endpoint_name, endpoint in aws_vpc_endpoint.interface_endpoints :
    endpoint_name => {
      id           = endpoint.id
      arn          = endpoint.arn
      service_name = endpoint.service_name
      vpc_id       = endpoint.vpc_id
      subnet_ids   = endpoint.subnet_ids
      tags         = endpoint.tags
    }
  }
}

output "validation_errors" {
  description = "External connectivity VPC validation errors"
  value       = local.vpc_validation_errors
}

output "route53_profile" {
  description = "Route 53 Profile for shared endpoints"
  value = {
    id   = aws_route53profiles_profile.shared_endpoints.id
    arn  = aws_route53profiles_profile.shared_endpoints.arn
    name = aws_route53profiles_profile.shared_endpoints.name
    tags = aws_route53profiles_profile.shared_endpoints.tags
  }
}

output "hub_internal_transit_gateway_attachment" {
  description = "Hub internal transit gateway attachment for external-connectivity VPC"
  value = {
    id = aws_ec2_transit_gateway_vpc_attachment.external_connectivity_hub_internal.id
  }
}

output "hub_internal_transit_gateway_route_table" {
  description = "Hub internal transit gateway route table for external-connectivity VPC"
  value = {
    id   = aws_ec2_transit_gateway_route_table.external_connectivity_hub_internal_route_table.id
    arn  = aws_ec2_transit_gateway_route_table.external_connectivity_hub_internal_route_table.arn
    tags = aws_ec2_transit_gateway_route_table.external_connectivity_hub_internal_route_table.tags
  }
}