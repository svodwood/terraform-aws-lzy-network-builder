output "vpc" {
  description = "VPC configuration and details"
  value = {
    id                    = aws_vpc.spoke_vpc.id
    name                  = var.vpc_name
    cidr_block            = aws_vpc.spoke_vpc.cidr_block
    account               = var.vpc_config.account
    type                  = var.vpc_config.type
    risk                  = var.vpc_config.risk
    availability_zone_ids = var.vpc_config.availability_zone_ids
    tags                  = aws_vpc.spoke_vpc.tags
  }
}

output "subnets" {
  description = "Map of subnet configurations and IDs"
  value = {
    for subnet_key, subnet_config in module.foundation.subnet_resources :
    subnet_key => {
      id                   = aws_subnet.subnets[subnet_key].id
      arn                  = aws_subnet.subnets[subnet_key].arn
      cidr_block           = subnet_config.cidr_block
      vpc_id               = aws_vpc.spoke_vpc.id
      vpc_name             = var.vpc_name
      subnet_name          = subnet_config.subnet_name
      availability_zone_id = subnet_config.availability_zone_id
      account              = var.vpc_config.account
      type                 = var.vpc_config.type
      risk                 = var.vpc_config.risk
      is_shared            = subnet_config.is_shared
      is_user              = subnet_config.is_user
      is_technical         = subnet_config.is_technical
      is_relay             = try(subnet_config.is_relay, false)
      is_inspection        = try(subnet_config.is_inspection, false)
      is_public_endpoints  = try(subnet_config.is_public_endpoints, false)
      tags                 = aws_subnet.subnets[subnet_key].tags
    }
  }
}

output "subnet_route_tables" {
  description = "Map of subnet route tables"
  value = {
    for subnet_key, _ in module.foundation.subnet_resources :
    subnet_key => {
      id   = aws_route_table.subnet_route_tables[subnet_key].id
      arn  = aws_route_table.subnet_route_tables[subnet_key].arn
      tags = aws_route_table.subnet_route_tables[subnet_key].tags
    }
  }
}

output "internet_gateway" {
  description = "Internet Gateway details (if created)"
  value = var.vpc_config.type == "public" ? {
    id   = aws_internet_gateway.spoke_igw[0].id
    arn  = aws_internet_gateway.spoke_igw[0].arn
    tags = aws_internet_gateway.spoke_igw[0].tags
  } : null
}

output "igw_route_table" {
  description = "IGW Route Table details (if created)"
  value = var.vpc_config.type == "public" ? {
    id   = aws_route_table.igw_route_table[0].id
    arn  = aws_route_table.igw_route_table[0].arn
    tags = aws_route_table.igw_route_table[0].tags
  } : null
}

output "transit_gateway_attachment" {
  description = "Transit Gateway VPC attachment for this spoke VPC"
  value = {
    id                 = aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment.id
    transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment.transit_gateway_id
    vpc_id             = aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment.vpc_id
    subnet_ids         = aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment.subnet_ids
    subnet_type        = "relay"
    availability_zones = [
      for subnet_key, subnet_config in module.foundation.subnet_resources :
      subnet_config.availability_zone_id
      if subnet_config.is_relay
    ]
    tags     = aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment.tags
    vpc_name = var.vpc_name
  }
}

output "transit_gateway_route_table" {
  description = "Individual Transit Gateway route table for this spoke VPC"
  value = {
    id                 = aws_ec2_transit_gateway_route_table.spoke_route_table.id
    transit_gateway_id = aws_ec2_transit_gateway_route_table.spoke_route_table.transit_gateway_id
    tags               = aws_ec2_transit_gateway_route_table.spoke_route_table.tags
    vpc_name           = var.vpc_name
  }
}

output "subnet_allocation_debug" {
  description = "Subnet allocation details for debugging (from vpc-foundation module)"
  value       = module.foundation.vpc_space_calculation
}

output "validation_errors" {
  description = "VPC foundation validation errors"
  value       = module.foundation.validation_errors
}
