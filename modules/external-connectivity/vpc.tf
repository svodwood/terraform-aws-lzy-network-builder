# External Connectivity VPC
resource "aws_vpc" "external_connectivity" {
  cidr_block           = local.vpc_data.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.vpc_data.tags, {
    Name = "external-connectivity"
  })
}
