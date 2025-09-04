# Transit Gateway Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_tgw_attachment" {
  subnet_ids = [
    for subnet_key, subnet_config in module.foundation.subnet_resources :
    aws_subnet.subnets[subnet_key].id
    if subnet_config.is_relay
  ]

  transit_gateway_id     = var.spoke_connectivity_transit_gateway.id
  vpc_id                 = aws_vpc.spoke_vpc.id
  appliance_mode_support = "enable"

  tags = merge(local.vpc_tags, {
    Name = "${var.vpc_name}-tgw-attachment"
  })

  depends_on = [
    aws_subnet.subnets
  ]
}

# Create individual TGW route table for this spoke VPC
resource "aws_ec2_transit_gateway_route_table" "spoke_route_table" {
  transit_gateway_id = var.spoke_connectivity_transit_gateway.id

  tags = merge(var.vpc_config.tags, var.default_tags, {
    Name = "${var.vpc_name}-tgw-spoke-rt"
  })

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment
  ]
}

# Associate VPC attachment with its own spoke route table
resource "aws_ec2_transit_gateway_route_table_association" "spoke_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_route_table.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment,
    aws_ec2_transit_gateway_route_table.spoke_route_table
  ]
}

# Create route in the hub firewall route table for this spoke VPC CIDR
resource "aws_ec2_transit_gateway_route" "spoke_vpc_route" {
  destination_cidr_block         = var.vpc_config.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment.id
  transit_gateway_route_table_id = values(var.spoke_connectivity_transit_gateway_firewall_route_tables)[0].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.spoke_tgw_attachment,
    aws_ec2_transit_gateway_route_table_association.spoke_association
  ]
}

# Default route in spoke route table to send all traffic through hub for inspection
resource "aws_ec2_transit_gateway_route" "spoke_default_route" {
  destination_cidr_block = "0.0.0.0/0"

  transit_gateway_attachment_id  = values(var.spoke_connectivity_transit_gateway_attachments)[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_route_table.id

  depends_on = [
    aws_ec2_transit_gateway_route_table.spoke_route_table,
    aws_ec2_transit_gateway_route_table_association.spoke_association
  ]
}
