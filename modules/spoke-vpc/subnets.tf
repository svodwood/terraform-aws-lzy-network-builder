# Subnets
resource "aws_subnet" "subnets" {
  for_each = module.foundation.subnet_resources

  vpc_id               = aws_vpc.spoke_vpc.id
  cidr_block           = each.value.cidr_block
  availability_zone_id = each.value.availability_zone_id

  # Enable public IP assignment for public endpoints subnets
  map_public_ip_on_launch = try(each.value.is_public_endpoints, false)

  tags = merge(local.vpc_tags, {
    Name = "${var.vpc_name}-${each.value.subnet_name}-${each.value.availability_zone_id}"
  })
}

# Route Tables
resource "aws_route_table" "subnet_route_tables" {
  for_each = module.foundation.subnet_resources

  vpc_id = aws_vpc.spoke_vpc.id

  tags = merge(local.vpc_tags, {
    Name = "${var.vpc_name}-${each.value.subnet_name}-${each.value.availability_zone_id}-rt"
  })
}

# Route Table Associations
resource "aws_route_table_association" "subnet_associations" {
  for_each = module.foundation.subnet_resources

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.subnet_route_tables[each.key].id
}
