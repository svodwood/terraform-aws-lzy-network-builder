
output "spoke_vpcs" {
  description = "Map of VPC configurations and IDs"
  value       = local.vpcs
}

output "spoke_subnets" {
  description = "Map of subnet configurations and IDs"
  value       = local.subnets
}


output "spoke_igw_route_tables" {
  description = "Internet Gateway route tables for public VPCs"
  value       = local.igw_route_tables
}

output "hub_vpc" {
  description = "Hub VPC information"
  value       = module.hub.vpc
}

output "hub_subnets" {
  description = "Hub VPC subnets"
  value       = module.hub.subnets
}

output "hub_route_tables" {
  description = "Hub VPC route tables"
  value       = module.hub.route_tables
}
