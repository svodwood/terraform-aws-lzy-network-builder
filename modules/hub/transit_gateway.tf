# Hub Module - Transit Gateway Resources
# Creates Transit Gateway, TGW attachments, TGW route tables, and TGW routing

# Create Transit Gateway for spoke connectivity
resource "aws_ec2_transit_gateway" "spoke_connectivity_transit_gateway" {
  description                     = "Transit Gateway for ${local.hub_vpc_name} spoke connectivity"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(local.vpc_tags, {
    Name = "${local.hub_vpc_name}-spoke-connectivity-tgw"
  })
}

# Attach Transit Gateway to relay subnets (AWS best practice for TGW attachments)
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_connectivity_tgw_attachment" {
  subnet_ids = [
    for subnet_key, subnet_config in local.subnet_resources :
    aws_subnet.hub[subnet_key].id
    if subnet_config.vpc_name == local.hub_vpc_name && subnet_config.is_relay
  ]
  transit_gateway_id     = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.id
  vpc_id                 = aws_vpc.hub_vpc.id
  appliance_mode_support = "enable"

  tags = merge(local.vpc_tags, {
    Name = "${local.hub_vpc_name}-spoke-connectivity-tgw-attachment"
  })

  depends_on = [
    aws_subnet.hub,
    aws_ec2_transit_gateway.spoke_connectivity_transit_gateway
  ]
}

# Transit Gateway Route Tables
# Firewall route table for hub VPC - handles return traffic routing
resource "aws_ec2_transit_gateway_route_table" "firewall_route_table" {
  transit_gateway_id = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.id

  tags = merge(local.vpc_tags, {
    Name = "${local.hub_vpc_name}-spoke-connectivity-tgw-firewall-rt"
  })

  depends_on = [aws_ec2_transit_gateway.spoke_connectivity_transit_gateway]
}

# Associate hub VPC attachment with firewall route table
resource "aws_ec2_transit_gateway_route_table_association" "hub_firewall_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_connectivity_tgw_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall_route_table.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.spoke_connectivity_tgw_attachment,
    aws_ec2_transit_gateway_route_table.firewall_route_table
  ]
}

# Hub Internal Transit Gateway for hub user-defined subnets to external-connectivity VPC
resource "aws_ec2_transit_gateway" "hub_internal_transit_gateway" {
  description                     = "Transit Gateway for ${local.hub_vpc_name} internal connectivity to shared endpoints"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(local.vpc_tags, {
    Name = "${local.hub_vpc_name}-internal-tgw"
  })
}

# Hub Internal Transit Gateway attachment to Hub VPC relay subnets
resource "aws_ec2_transit_gateway_vpc_attachment" "hub_internal_tgw_attachment" {
  subnet_ids = [
    for subnet_key, subnet_config in local.subnet_resources :
    aws_subnet.hub[subnet_key].id
    if subnet_config.vpc_name == local.hub_vpc_name && subnet_config.is_relay
  ]
  transit_gateway_id     = aws_ec2_transit_gateway.hub_internal_transit_gateway.id
  vpc_id                 = aws_vpc.hub_vpc.id
  appliance_mode_support = "disable"

  tags = merge(local.vpc_tags, {
    Name = "${local.hub_vpc_name}-internal-tgw-attachment"
  })

  depends_on = [
    aws_subnet.hub,
    aws_ec2_transit_gateway.hub_internal_transit_gateway
  ]
}

# Hub Internal Transit Gateway route table for hub VPC attachment
resource "aws_ec2_transit_gateway_route_table" "hub_internal_route_table" {
  transit_gateway_id = aws_ec2_transit_gateway.hub_internal_transit_gateway.id

  tags = merge(local.vpc_tags, {
    Name = "${local.hub_vpc_name}-internal-tgw-rt"
  })

  depends_on = [aws_ec2_transit_gateway.hub_internal_transit_gateway]
}

# Associate hub internal TGW attachment with hub route table
resource "aws_ec2_transit_gateway_route_table_association" "hub_internal_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub_internal_tgw_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub_internal_route_table.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.hub_internal_tgw_attachment,
    aws_ec2_transit_gateway_route_table.hub_internal_route_table
  ]
}
