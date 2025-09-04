# Example outputs to demonstrate what the module provides
output "hub_vpc_id" {
  description = "ID of the hub VPC"
  value       = module.lzy_network_builder.hub_vpc.id
}

output "spoke_vpc_ids" {
  description = "Map of spoke VPC names to their IDs"
  value       = { for name, vpc in module.lzy_network_builder.spoke_vpcs : name => vpc.id }
}