# Spoke VPC Module
# Creates spoke VPCs for workloads and applications

locals {
  vpcs = {
    for vpc_name, vpc_module in module.spoke_vpc : vpc_name => vpc_module.vpc
  }

  subnets = merge([
    for vpc_name, vpc_module in module.spoke_vpc : vpc_module.subnets
  ]...)

  subnet_route_tables = merge([
    for vpc_name, vpc_module in module.spoke_vpc : vpc_module.subnet_route_tables
  ]...)

  igw_route_tables = {
    for vpc_name, vpc_module in module.spoke_vpc : vpc_name => vpc_module.igw_route_table
    if vpc_module.igw_route_table != null
  }

  internet_gateways = {
    for vpc_name, vpc_module in module.spoke_vpc : vpc_name => vpc_module.internet_gateway
    if vpc_module.internet_gateway != null
  }

  inspection_subnets = merge([
    for vpc_name, vpc_module in module.spoke_vpc : {
      for subnet_key, subnet in vpc_module.subnets :
      subnet_key => subnet
      if subnet.is_inspection
    }
  ]...)

  pub_endpoints_subnets = merge([
    for vpc_name, vpc_module in module.spoke_vpc : {
      for subnet_key, subnet in vpc_module.subnets :
      subnet_key => subnet
      if subnet.is_public_endpoints
    }
  ]...)

  # User-defined subnets in high-risk VPCs (used for inter-subnet inspection routing)
  high_risk_user_subnets = [
    for subnet_key, subnet in local.subnets : subnet_key
    if subnet.is_user && local.vpcs[subnet.vpc_name].risk == "high"
  ]

  # Inspection subnets in public VPCs (need IGW routing for egress after inspection)
  public_inspection_subnets = {
    for subnet_key, subnet in local.inspection_subnets :
    subnet_key => subnet
    if local.vpcs[subnet.vpc_name].type == "public"
  }

  # Subnets that require firewall inspection (public VPCs or high-risk VPCs)
  inspection_required_subnets = {
    for subnet_key, subnet in local.inspection_subnets :
    subnet_key => subnet
    if local.vpcs[subnet.vpc_name].type == "public" ||
    local.vpcs[subnet.vpc_name].risk == "high"
  }

  firewall_endpoints = merge(
    # AWS Network Firewall endpoints
    local.is_aws_firewall ? {
      for key, association in aws_networkfirewall_vpc_endpoint_association.spoke_to_hub_firewall :
      key => [
        for state in association.vpc_endpoint_association_status[0].association_sync_state :
        state.attachment[0].endpoint_id
      ][0]
    } : {},
    # GWLB endpoints
    local.is_gwlb_firewall ? {
      for key, endpoint in aws_vpc_endpoint.spoke_to_hub_gwlb :
      key => endpoint.id
    } : {}
  )

  # Map each subnet to its corresponding inspection subnet's firewall endpoint
  subnet_firewall_endpoints = {
    for subnet_key, subnet in local.subnets : subnet_key => (
      lookup(local.firewall_endpoints, [
        for inspection_key, inspection_subnet in local.inspection_subnets :
        inspection_key
        if inspection_subnet.vpc_name == subnet.vpc_name &&
        inspection_subnet.availability_zone_id == subnet.availability_zone_id
      ][0], null)
    )
  }
}

# Create spoke VPCs
module "spoke_vpc" {
  source = "./modules/spoke-vpc"

  for_each = local.spoke_networks_config

  vpc_name                       = each.key
  vpc_config                     = each.value
  network_account_id             = var.network_account_id
  default_tags                   = var.default_tags
  spoke_inspection_subnet_suffix = var.spoke_inspection_subnet_suffix
  spoke_relay_subnet_suffix      = var.spoke_relay_subnet_suffix

  # Network security hub integration
  spoke_connectivity_transit_gateway = module.hub.spoke_connectivity_transit_gateway

  # Firewall routing
  spoke_connectivity_transit_gateway_firewall_route_tables = module.hub.spoke_connectivity_transit_gateway_firewall_route_tables
  spoke_connectivity_transit_gateway_attachments           = module.hub.spoke_connectivity_transit_gateway_attachments

  # Route 53 Profile for VPC endpoint sharing
  shared_endpoints_profile = module.external_connectivity.route53_profile

  depends_on = [module.hub]
}

# AWS Network Firewall VPC Endpoints in Spoke Inspection Subnets
resource "aws_networkfirewall_vpc_endpoint_association" "spoke_to_hub_firewall" {
  for_each = local.is_aws_firewall ? local.inspection_required_subnets : {}

  firewall_arn = module.firewall.firewall_arn
  vpc_id       = each.value.vpc_id

  subnet_mapping {
    subnet_id = each.value.id
  }

  depends_on = [
    module.spoke_vpc,
    module.hub,
    module.firewall
  ]
}

# GWLB VPC Endpoints in Spoke Inspection Subnets
resource "aws_vpc_endpoint" "spoke_to_hub_gwlb" {
  for_each = local.is_gwlb_firewall ? local.inspection_required_subnets : {}

  service_name      = module.firewall.gwlb_endpoint_service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = each.value.vpc_id
  subnet_ids        = [each.value.id]

  tags = merge(var.default_tags, {
    Name = "gwlb-endpoint-${each.key}"
  })

  depends_on = [
    module.spoke_vpc,
    module.hub,
    module.firewall
  ]
}

# 1. IGW Route Table: Route traffic destined for pub-endpoints subnets through inspection endpoints
resource "aws_route" "igw_to_inspection_for_pub_endpoints" {
  for_each = local.pub_endpoints_subnets

  route_table_id         = local.igw_route_tables[each.value.vpc_name].id
  destination_cidr_block = each.value.cidr_block
  vpc_endpoint_id        = local.subnet_firewall_endpoints[each.key]

  depends_on = [
    module.spoke_vpc,
    module.firewall
  ]
}

# 2. Inspection Subnet Route Table: Default route to IGW for egress traffic after inspection (only for public VPCs)
resource "aws_route" "inspection_to_igw" {
  for_each = local.public_inspection_subnets

  route_table_id         = local.subnet_route_tables[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = local.internet_gateways[each.value.vpc_name].id

  depends_on = [
    module.spoke_vpc
  ]
}

# 3. Public Endpoints Subnet Route Table: Route return traffic through inspection firewall
resource "aws_route" "pub_endpoints_to_inspection" {
  for_each = local.pub_endpoints_subnets

  route_table_id         = local.subnet_route_tables[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.subnet_firewall_endpoints[each.key]

  depends_on = [
    module.spoke_vpc,
    module.firewall
  ]
}

# 4. High-Risk VPC Inter-Subnet Inspection: Route traffic between user-defined subnets through inspection endpoints
resource "aws_route" "high_risk_inter_subnet_inspection" {
  for_each = {
    for combo in setproduct(
      # Source subnets: user-defined subnets in high-risk VPCs
      local.high_risk_user_subnets,
      # Destination subnets: user-defined subnets in high-risk VPCs  
      local.high_risk_user_subnets
      ) : "${combo[0]}-to-${combo[1]}" => {
      source_subnet_key = combo[0]
      dest_subnet_key   = combo[1]
      source_subnet     = local.subnets[combo[0]]
      dest_subnet       = local.subnets[combo[1]]
    }
    # Only create routes between different subnets in the same VPC (allow cross-AZ traffic)
    if local.subnets[combo[0]].vpc_name == local.subnets[combo[1]].vpc_name &&
    local.subnets[combo[0]].subnet_name != local.subnets[combo[1]].subnet_name
  }

  route_table_id         = local.subnet_route_tables[each.value.source_subnet_key].id
  destination_cidr_block = each.value.dest_subnet.cidr_block
  vpc_endpoint_id        = local.subnet_firewall_endpoints[each.value.source_subnet_key]

  depends_on = [
    module.spoke_vpc,
    module.firewall
  ]
}

# 5. User-Defined Subnet Route Tables: Default route to Transit Gateway for centralized egress
resource "aws_route" "user_subnets_to_tgw" {
  for_each = {
    for subnet_key, subnet in local.subnets : subnet_key => subnet
    if subnet.is_user
  }

  route_table_id         = local.subnet_route_tables[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.hub.spoke_connectivity_transit_gateway.id

  depends_on = [
    module.spoke_vpc,
    module.hub
  ]
}
