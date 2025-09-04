# Unified routing endpoints - all firewall types
output "routing_endpoints" {
  description = "Endpoints to use for routing (firewall endpoints or GLB endpoints), keyed by AZ ID"
  value = (
    local.is_aws_network_firewall ? {
      for sync_state in aws_networkfirewall_firewall.network_firewall[0].firewall_status[0].sync_states :
      # Find the AZ ID by matching the subnet ID from sync_state to our firewall_subnets
      [for k, v in var.firewall_subnets : v.availability_zone_id if v.subnet_id == sync_state.attachment[0].subnet_id][0] => sync_state.attachment[0].endpoint_id
    } :
    local.is_gateway_load_balancer ? {
      for i, endpoint in aws_vpc_endpoint.gateway_load_balancer_hub :
      values(var.firewall_subnets)[i].availability_zone_id => endpoint.id
    } : {}
  )
}

# AWS Network Firewall ARN
output "firewall_arn" {
  description = "ARN of the Network Firewall - only populated for AWS Network Firewall type"
  value       = local.is_aws_network_firewall ? aws_networkfirewall_firewall.network_firewall[0].arn : null
}

# Gateway Load Balancer VPC Endpoint Service Name
output "gwlb_endpoint_service_name" {
  description = "VPC Endpoint Service name for Gateway Load Balancer - only populated for GWLB type"
  value       = local.is_gateway_load_balancer ? aws_vpc_endpoint_service.gateway_load_balancer[0].service_name : null
}
