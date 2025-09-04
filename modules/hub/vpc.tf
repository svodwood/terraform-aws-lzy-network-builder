# Hub Module - Core VPC Infrastructure
# Creates VPC, Internet Gateway, NAT Gateway, and IGW route tables

# Create hub VPC
resource "aws_vpc" "hub_vpc" {
  cidr_block           = local.vpc_config.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.vpc_tags, {
    Name = local.hub_vpc_name
  })
}

# Internet Gateway for hub VPC egress traffic
resource "aws_internet_gateway" "hub_igw" {
  vpc_id = aws_vpc.hub_vpc.id

  tags = merge(local.vpc_tags, {
    Name = "${local.hub_vpc_name}-igw"
  })

  depends_on = [aws_vpc.hub_vpc]
}

# NAT Gateways in egress subnets (one per AZ)
resource "aws_eip" "hub_nat" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_egress
  }

  domain = "vpc"

  tags = merge(local.vpc_tags, {
    Name = "${each.value.vpc_name}-nat-${each.value.availability_zone_id}"
  })

  depends_on = [aws_internet_gateway.hub_igw]
}

resource "aws_nat_gateway" "hub_nat" {
  for_each = {
    for key, subnet in local.subnet_resources : key => subnet
    if subnet.is_egress
  }

  allocation_id = aws_eip.hub_nat[each.key].id
  subnet_id     = aws_subnet.hub[each.key].id

  tags = merge(local.vpc_tags, {
    Name = "${each.value.vpc_name}-nat-${each.value.availability_zone_id}"
  })

  depends_on = [
    aws_internet_gateway.hub_igw,
    aws_subnet.hub
  ]
}

# S3 Gateway Endpoint for hub VPC user-defined subnets
resource "aws_vpc_endpoint" "hub_s3_gateway" {
  vpc_id            = aws_vpc.hub_vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    for subnet_key, rt in aws_route_table.hub_subnet_routes : rt.id
    if local.subnet_resources[subnet_key].is_user
  ]

  tags = merge(local.vpc_tags, {
    Name = "${local.hub_vpc_name}-s3-gateway-endpoint"
  })

  depends_on = [
    aws_vpc.hub_vpc,
    aws_route_table.hub_subnet_routes
  ]
}
