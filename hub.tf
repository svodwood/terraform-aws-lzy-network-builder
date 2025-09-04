# Network Security VPC Module
module "hub" {
  source = "./modules/hub"

  hub_definition             = var.hub_definition
  network_account_id         = var.network_account_id
  hub_relay_subnet_suffix    = var.hub_relay_subnet_suffix
  hub_firewall_subnet_suffix = var.hub_firewall_subnet_suffix
  hub_egress_subnet_suffix   = var.hub_egress_subnet_suffix
  external_connectivity_cidr = var.external_connectivity_cidr
  default_tags               = var.default_tags
  region                     = split(".", basename(var.hub_definition))[0]
}

# Network Firewall Module in Hub
module "firewall" {
  source = "./modules/firewall"

  vpc_id                         = module.hub.vpc.id
  vpc_name                       = module.hub.vpc.vpc_name
  network_account_id             = var.network_account_id
  firewall_type                  = var.firewall_type
  aws_network_firewall_allow_all = var.aws_network_firewall_allow_all
  firewall_subnets = {
    for subnet_key, subnet in module.hub.subnets : subnet.availability_zone_id => {
      subnet_id            = subnet.id
      availability_zone_id = subnet.availability_zone_id
      vpc_name             = subnet.vpc_name
    }
    if subnet.is_firewall
  }
  default_tags = var.default_tags
  vpc_tags     = module.hub.vpc.tags

  depends_on = [
    module.hub
  ]
}

# External Connectivity VPC Module
module "external_connectivity" {
  source = "./modules/external-connectivity"

  external_connectivity_cidr                    = var.external_connectivity_cidr
  relay_subnet_suffix                           = var.external_connectivity_relay_subnet_suffix
  endpoints_subnet_suffix                       = var.external_connectivity_endpoints_subnet_suffix
  network_account_id                            = var.network_account_id
  region                                        = split(".", basename(var.hub_definition))[0]
  spoke_connectivity_transit_gateway            = module.hub.spoke_connectivity_transit_gateway
  spoke_connectivity_transit_gateway_attachment = module.hub.spoke_connectivity_transit_gateway_attachments[module.hub.vpc.vpc_name]
  hub_firewall_route_table                      = module.hub.spoke_connectivity_transit_gateway_firewall_route_tables[module.hub.vpc.vpc_name]
  hub_internal_transit_gateway                  = module.hub.hub_internal_transit_gateway
  hub_vpc_cidr                                  = module.hub.vpc.cidr_block
  availability_zone_ids                         = module.hub.vpc.availability_zone_ids
  vpc_endpoints_config                          = module.hub.vpc_endpoints_config
  default_tags                                  = var.default_tags

  depends_on = [module.hub]
}

# Firewall routing configuration

resource "aws_route" "relay_to_firewall" {
  for_each = module.hub.relay_route_tables

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.firewall.routing_endpoints[each.value.availability_zone_id]

  depends_on = [
    module.hub,
    module.firewall
  ]
}

# RFC 1918 routes for egress subnets to AZ-specific firewall endpoints
resource "aws_route" "egress_to_firewall_rfc1918_10" {
  for_each = module.hub.egress_route_tables

  route_table_id         = each.value.id
  destination_cidr_block = "10.0.0.0/8"
  vpc_endpoint_id        = module.firewall.routing_endpoints[each.value.availability_zone_id]

  depends_on = [
    module.hub,
    module.firewall
  ]
}

resource "aws_route" "egress_to_firewall_rfc1918_172" {
  for_each = module.hub.egress_route_tables

  route_table_id         = each.value.id
  destination_cidr_block = "172.16.0.0/12"
  vpc_endpoint_id        = module.firewall.routing_endpoints[each.value.availability_zone_id]

  depends_on = [
    module.hub,
    module.firewall
  ]
}

resource "aws_route" "egress_to_firewall_rfc1918_192" {
  for_each = module.hub.egress_route_tables

  route_table_id         = each.value.id
  destination_cidr_block = "192.168.0.0/16"
  vpc_endpoint_id        = module.firewall.routing_endpoints[each.value.availability_zone_id]

  depends_on = [
    module.hub,
    module.firewall
  ]
}

# Firewall subnet route to external-connectivity VPC via TGW
resource "aws_route" "firewall_to_tgw_external_connectivity" {
  for_each = {
    for subnet_key, route_table in module.hub.route_tables : subnet_key => route_table
    if module.hub.subnets[subnet_key].is_firewall
  }

  route_table_id         = each.value.id
  destination_cidr_block = var.external_connectivity_cidr
  transit_gateway_id     = module.hub.spoke_connectivity_transit_gateway.id

  depends_on = [
    module.hub,
    module.external_connectivity
  ]
}

# Shared endpoints routing configuration - RFC 1918 routes back to spokes via firewall

# Transit Gateway route from hub to external-connectivity VPC
resource "aws_ec2_transit_gateway_route" "hub_to_external_connectivity" {
  destination_cidr_block         = var.external_connectivity_cidr
  transit_gateway_attachment_id  = module.external_connectivity.transit_gateway_attachment.id
  transit_gateway_route_table_id = module.hub.spoke_connectivity_transit_gateway_firewall_route_tables[module.hub.vpc.vpc_name].id

  depends_on = [
    module.hub,
    module.external_connectivity
  ]
}

# Hub internal route table to external-connectivity VPC
resource "aws_ec2_transit_gateway_route" "hub_internal_to_external_connectivity" {
  destination_cidr_block         = var.external_connectivity_cidr
  transit_gateway_attachment_id  = module.external_connectivity.hub_internal_transit_gateway_attachment.id
  transit_gateway_route_table_id = module.hub.hub_internal_transit_gateway_route_table.id

  depends_on = [
    module.hub,
    module.external_connectivity
  ]
}

# Route from external-connectivity to hub VPC
resource "aws_ec2_transit_gateway_route" "external_connectivity_to_hub_internal" {
  destination_cidr_block         = module.hub.vpc.cidr_block
  transit_gateway_attachment_id  = module.hub.hub_internal_transit_gateway_attachment.id
  transit_gateway_route_table_id = module.external_connectivity.hub_internal_transit_gateway_route_table.id

  depends_on = [
    module.hub,
    module.external_connectivity
  ]
}

# Route 53 Profile Association for Hub VPC
resource "aws_route53profiles_association" "hub_shared_endpoints" {
  name        = "shared-endpoints-${module.hub.vpc.vpc_name}"
  profile_id  = module.external_connectivity.route53_profile.id
  resource_id = module.hub.vpc.id

  tags = merge(var.default_tags, {
    Name = "${module.hub.vpc.vpc_name}-shared-endpoints-association"
  })

  depends_on = [
    module.hub,
    module.external_connectivity
  ]
}
