# Hub Module - Subnet Resources and Routing
# Creates subnets, subnet route tables, and subnet-level routing

# Create hub subnets
resource "aws_subnet" "hub" {
  for_each = local.subnet_resources

  vpc_id               = aws_vpc.hub_vpc.id
  availability_zone_id = each.value.availability_zone_id
  cidr_block           = each.value.cidr_block

  tags = merge(local.vpc_tags, {
    Name = "${each.value.vpc_name}-${each.value.subnet_name}-${each.value.availability_zone_id}"
  })

  depends_on = [aws_vpc.hub_vpc]
}

# Create route tables for each hub subnet
resource "aws_route_table" "hub_subnet_routes" {
  for_each = local.subnet_resources

  vpc_id = aws_vpc.hub_vpc.id

  tags = merge(local.vpc_tags, {
    Name = "${each.value.vpc_name}-${each.value.subnet_name}-${each.value.availability_zone_id}-rt"
  })

  depends_on = [aws_vpc.hub_vpc]
}

# Routes for egress subnets
resource "aws_route" "egress_to_igw" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_egress
  }

  route_table_id         = aws_route_table.hub_subnet_routes[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.hub_igw.id

  depends_on = [
    aws_route_table.hub_subnet_routes,
    aws_internet_gateway.hub_igw
  ]
}

# Routes for firewall subnets to NAT Gateway for outbound internet access
resource "aws_route" "firewall_to_nat" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_firewall
  }

  route_table_id         = aws_route_table.hub_subnet_routes[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.hub_nat[
    # Find the NAT gateway in the same AZ
    [for nat_key, nat_subnet in local.subnet_resources : nat_key
    if nat_subnet.is_egress && nat_subnet.availability_zone_id == each.value.availability_zone_id][0]
  ].id

  depends_on = [
    aws_route_table.hub_subnet_routes,
    aws_nat_gateway.hub_nat
  ]
}

# Routes for firewall subnets to Transit Gateway for RFC 1918 traffic
resource "aws_route" "firewall_to_tgw_rfc1918_10" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_firewall
  }

  route_table_id         = aws_route_table.hub_subnet_routes[each.key].id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.id

  depends_on = [
    aws_route_table.hub_subnet_routes,
    aws_ec2_transit_gateway.spoke_connectivity_transit_gateway
  ]
}

resource "aws_route" "firewall_to_tgw_rfc1918_172" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_firewall
  }

  route_table_id         = aws_route_table.hub_subnet_routes[each.key].id
  destination_cidr_block = "172.16.0.0/12"
  transit_gateway_id     = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.id

  depends_on = [
    aws_route_table.hub_subnet_routes,
    aws_ec2_transit_gateway.spoke_connectivity_transit_gateway
  ]
}

resource "aws_route" "firewall_to_tgw_rfc1918_192" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_firewall
  }

  route_table_id         = aws_route_table.hub_subnet_routes[each.key].id
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.spoke_connectivity_transit_gateway.id

  depends_on = [
    aws_route_table.hub_subnet_routes,
    aws_ec2_transit_gateway.spoke_connectivity_transit_gateway
  ]
}

# Routes for user-defined subnets to NAT Gateway for direct internet access
resource "aws_route" "user_subnets_to_nat" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_user
  }

  route_table_id         = aws_route_table.hub_subnet_routes[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.hub_nat[
    # Find the NAT gateway in the same AZ
    [for nat_key, nat_subnet in local.subnet_resources : nat_key
    if nat_subnet.is_egress && nat_subnet.availability_zone_id == each.value.availability_zone_id][0]
  ].id

  depends_on = [
    aws_route_table.hub_subnet_routes,
    aws_nat_gateway.hub_nat
  ]
}

# Routes for user-defined subnets to hub internal transit gateway for external VPC access
resource "aws_route" "user_subnets_to_hub_internal_tgw" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_user
  }

  route_table_id         = aws_route_table.hub_subnet_routes[each.key].id
  destination_cidr_block = var.external_connectivity_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.hub_internal_transit_gateway.id

  depends_on = [
    aws_route_table.hub_subnet_routes,
    aws_ec2_transit_gateway.hub_internal_transit_gateway
  ]
}

# Associate route tables with subnets
resource "aws_route_table_association" "hub_subnet_association" {
  for_each = local.subnet_resources

  subnet_id      = aws_subnet.hub[each.key].id
  route_table_id = aws_route_table.hub_subnet_routes[each.key].id

  depends_on = [
    aws_subnet.hub,
    aws_route_table.hub_subnet_routes
  ]
}
