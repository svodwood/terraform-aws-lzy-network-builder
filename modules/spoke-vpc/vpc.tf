# VPC Resource
resource "aws_vpc" "spoke_vpc" {
  cidr_block           = var.vpc_config.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.vpc_tags, {
    Name = var.vpc_name
  })
}

# Internet Gateway
resource "aws_internet_gateway" "spoke_igw" {
  count  = var.vpc_config.type == "public" ? 1 : 0
  vpc_id = aws_vpc.spoke_vpc.id

  tags = merge(local.vpc_tags, {
    Name = "${var.vpc_name}-igw"
  })
}

# IGW Route Table for edge-associated routing (public VPCs only)
resource "aws_route_table" "igw_route_table" {
  count = var.vpc_config.type == "public" ? 1 : 0

  vpc_id = aws_vpc.spoke_vpc.id

  tags = merge(local.vpc_tags, {
    Name = "${var.vpc_name}-igw-rt"
  })
}

# Associate IGW Route Table with Internet Gateway
resource "aws_route_table_association" "igw_association" {
  count = var.vpc_config.type == "public" ? 1 : 0

  route_table_id = aws_route_table.igw_route_table[0].id
  gateway_id     = aws_internet_gateway.spoke_igw[0].id
}
