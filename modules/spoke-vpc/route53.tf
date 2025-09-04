# Route 53 Profile Association for VPC endpoint sharing
resource "aws_route53profiles_association" "shared_endpoints" {
  count = var.shared_endpoints_profile != null ? 1 : 0

  name        = "shared-endpoints-${var.vpc_name}"
  profile_id  = var.shared_endpoints_profile.id
  resource_id = aws_vpc.spoke_vpc.id

  tags = merge(local.vpc_tags, {
    Name = "${var.vpc_name}-shared-endpoints-association"
  })
}
