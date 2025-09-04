# Transit Gateway Attachment for spoke connectivity
resource "aws_ec2_transit_gateway_vpc_attachment" "external_connectivity" {
  subnet_ids = [
    for subnet_key, subnet_config in local.subnet_resources :
    aws_subnet.external_connectivity[subnet_key].id
    if subnet_config.is_relay
  ]
  transit_gateway_id = var.spoke_connectivity_transit_gateway.id
  vpc_id             = aws_vpc.external_connectivity.id

  tags = merge(local.vpc_data.tags, {
    Name = "external-connectivity-tgw-attachment"
  })

  depends_on = [
    aws_subnet.external_connectivity
  ]
}

# Transit Gateway Route Table for spoke connectivity
resource "aws_ec2_transit_gateway_route_table" "external_connectivity_route_table" {
  transit_gateway_id = var.spoke_connectivity_transit_gateway.id

  tags = merge(var.default_tags, {
    Name = "external-connectivity-tgw-rt"
  })

  depends_on = [var.spoke_connectivity_transit_gateway]
}

# Associate external-connectivity VPC attachment with its route table
resource "aws_ec2_transit_gateway_route_table_association" "external_connectivity_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.external_connectivity.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.external_connectivity_route_table.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.external_connectivity,
    aws_ec2_transit_gateway_route_table.external_connectivity_route_table
  ]
}

# Default route in external-connectivity route table to hub (like spoke VPCs)
resource "aws_ec2_transit_gateway_route" "external_connectivity_default_route" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = var.spoke_connectivity_transit_gateway_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.external_connectivity_route_table.id

  depends_on = [
    aws_ec2_transit_gateway_route_table.external_connectivity_route_table,
    aws_ec2_transit_gateway_route_table_association.external_connectivity_association
  ]
}

# Internal Hub TGW attachment to External-connectivity VPC relay subnets
resource "aws_ec2_transit_gateway_vpc_attachment" "external_connectivity_hub_internal" {
  subnet_ids = [
    for subnet_key, subnet in local.subnet_resources : aws_subnet.external_connectivity[subnet_key].id
    if subnet.is_relay
  ]
  transit_gateway_id = var.hub_internal_transit_gateway.id
  vpc_id             = aws_vpc.external_connectivity.id

  tags = merge(local.vpc_data.tags, {
    Name = "external-connectivity-internal-tgw-attachment"
  })

  depends_on = [
    aws_subnet.external_connectivity
  ]
}

# Internal Hub TGW route table for external-connectivity VPC attachment
resource "aws_ec2_transit_gateway_route_table" "external_connectivity_hub_internal_route_table" {
  transit_gateway_id = var.hub_internal_transit_gateway.id

  tags = merge(var.default_tags, {
    Name = "external-connectivity-internal-tgw-rt"
  })

  depends_on = [var.hub_internal_transit_gateway]
}

# Associate external-connectivity Internal Hub TGW VPC attachment with external-connectivity route table
resource "aws_ec2_transit_gateway_route_table_association" "external_connectivity_hub_internal_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.external_connectivity_hub_internal.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.external_connectivity_hub_internal_route_table.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.external_connectivity_hub_internal,
    aws_ec2_transit_gateway_route_table.external_connectivity_hub_internal_route_table
  ]
}
