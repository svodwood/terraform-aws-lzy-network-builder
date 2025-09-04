# VPC Interface Endpoints for shared access across spoke VPCs
# These endpoints are hosted in the external-connectivity VPC and accessible to all spokes as well as the hub

# Define restrictive default policy for VPC endpoints when no policy is specified
locals {
  default_vpc_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "*"
        Resource  = "*"
      }
    ]
  })
}

# Create security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "external-connectivity-vpc-endpoints-"
  description = "Security group for shared VPC interface endpoints in external-connectivity VPC"
  vpc_id      = aws_vpc.external_connectivity.id

  ingress {
    description = "HTTPS for VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.default_tags,
    local.vpc_data.tags,
    {
      Name = "external-connectivity-vpc-endpoints-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Create VPC interface endpoints based on YAML configuration
resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = local.interface_endpoints

  vpc_id             = each.value.vpc_id
  service_name       = "com.amazonaws.${var.region}.${each.value.service_name}"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = each.value.subnet_ids
  security_group_ids = [each.value.security_group_id]

  private_dns_enabled = true

  policy = coalesce(each.value.policy, local.default_vpc_endpoint_policy)

  tags = merge(
    var.default_tags,
    each.value.vpc_tags,
    {
      Name = "${each.value.vpc_name}-${each.value.service_name}-endpoint"
    }
  )

  depends_on = [aws_vpc_endpoint.s3_gateway]
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.external_connectivity.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    for subnet_key, route_table in aws_route_table.external_connectivity_subnet_routes : route_table.id
    if local.subnet_resources[subnet_key].is_shared_endpoints
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "*"
      }
    ]
  })

  tags = merge(
    var.default_tags,
    local.vpc_config.tags,
    {
      Name = "external-connectivity-s3-gateway-endpoint"
    }
  )
}

# Route 53 Profile for shared VPC endpoints
resource "aws_route53profiles_profile" "shared_endpoints" {
  name = "shared-endpoints"

  tags = merge(var.default_tags, {
    Name = "shared-endpoints"
  })
}

# Associate each VPC interface endpoint with the Route 53 Profile
resource "aws_route53profiles_resource_association" "shared_endpoints" {
  for_each = aws_vpc_endpoint.interface_endpoints

  name         = each.key
  profile_id   = aws_route53profiles_profile.shared_endpoints.id
  resource_arn = each.value.arn

  depends_on = [
    aws_vpc_endpoint.interface_endpoints,
    aws_route53profiles_profile.shared_endpoints
  ]
}

# Simple routing for endpoints subnets - RFC1918 routes to TGW
resource "aws_route" "endpoints_to_tgw_rfc1918_10" {
  for_each = {
    for subnet_key, subnet in local.subnet_resources : subnet_key => subnet
    if subnet.is_shared_endpoints
  }

  route_table_id         = aws_route_table.external_connectivity_subnet_routes[each.key].id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = var.spoke_connectivity_transit_gateway.id

  depends_on = [
    aws_route_table.external_connectivity_subnet_routes,
    aws_ec2_transit_gateway_vpc_attachment.external_connectivity
  ]
}

resource "aws_route" "endpoints_to_tgw_rfc1918_172" {
  for_each = {
    for subnet_key, subnet in local.subnet_resources : subnet_key => subnet
    if subnet.is_shared_endpoints
  }

  route_table_id         = aws_route_table.external_connectivity_subnet_routes[each.key].id
  destination_cidr_block = "172.16.0.0/12"
  transit_gateway_id     = var.spoke_connectivity_transit_gateway.id

  depends_on = [
    aws_route_table.external_connectivity_subnet_routes,
    aws_ec2_transit_gateway_vpc_attachment.external_connectivity
  ]
}

resource "aws_route" "endpoints_to_tgw_rfc1918_192" {
  for_each = {
    for subnet_key, subnet in local.subnet_resources : subnet_key => subnet
    if subnet.is_shared_endpoints
  }

  route_table_id         = aws_route_table.external_connectivity_subnet_routes[each.key].id
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = var.spoke_connectivity_transit_gateway.id

  depends_on = [
    aws_route_table.external_connectivity_subnet_routes,
    aws_ec2_transit_gateway_vpc_attachment.external_connectivity
  ]
}

# Route from endpoints subnets to hub VPC via Hub Internal TGW
resource "aws_route" "endpoints_to_hub_via_hub_internal_tgw" {
  for_each = {
    for subnet_key, subnet in local.subnet_resources : subnet_key => subnet
    if subnet.is_shared_endpoints
  }

  route_table_id         = aws_route_table.external_connectivity_subnet_routes[each.key].id
  destination_cidr_block = var.hub_vpc_cidr
  transit_gateway_id     = var.hub_internal_transit_gateway.id

  depends_on = [
    aws_route_table.external_connectivity_subnet_routes,
    aws_ec2_transit_gateway_vpc_attachment.external_connectivity_hub_internal
  ]
}
