# External Connectivity Module - Subnet Resources and Routing
# Creates subnets, subnet route tables, and subnet-level routing

# Create external connectivity subnets
resource "aws_subnet" "external_connectivity" {
  for_each = local.subnet_resources

  vpc_id               = aws_vpc.external_connectivity.id
  availability_zone_id = each.value.availability_zone_id
  cidr_block           = each.value.cidr_block

  tags = merge(var.default_tags, local.vpc_data.tags, {
    Name = "${each.value.vpc_name}-${each.value.subnet_name}-${each.value.availability_zone_id}"
  })

  depends_on = [aws_vpc.external_connectivity]
}

# Create route tables for each external connectivity subnet
resource "aws_route_table" "external_connectivity_subnet_routes" {
  for_each = local.subnet_resources

  vpc_id = aws_vpc.external_connectivity.id

  tags = merge(var.default_tags, local.vpc_data.tags, {
    Name = "${each.value.vpc_name}-${each.value.subnet_name}-${each.value.availability_zone_id}-rt"
  })

  depends_on = [aws_vpc.external_connectivity]
}

# Route Table Associations
resource "aws_route_table_association" "subnet_associations" {
  for_each = local.subnet_resources

  subnet_id      = aws_subnet.external_connectivity[each.key].id
  route_table_id = aws_route_table.external_connectivity_subnet_routes[each.key].id
}
