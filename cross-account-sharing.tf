# Cross-Account Sharing for Spoke VPCs
# Handles AWS RAM sharing and cross-account tagging for spoke VPCs

locals {
  # Extract unique principal accounts that need RAM sharing
  ram_sharing_accounts = distinct([
    for vpc_name, vpc_config in local.spoke_networks_config : tostring(vpc_config.account)
    if vpc_config.account != var.network_account_id
  ])

  # Filter subnets that should be shared (user-defined + pub-endpoints only)
  shared_subnets = {
    for subnet_key, subnet in local.subnets : subnet_key => subnet
    if subnet.is_user || (subnet.is_technical && subnet.is_public_endpoints)
  }

  # Group shared subnets by account for RAM sharing
  subnets_by_account = {
    for account_id in local.ram_sharing_accounts : account_id => {
      for subnet_key, subnet in local.shared_subnets : subnet_key => subnet
      if tostring(local.spoke_networks_config[subnet.vpc_name].account) == account_id
    }
  }
}

# RAM Resource Share - one per target account
resource "aws_ram_resource_share" "cross_account_subnets" {
  for_each = toset(local.ram_sharing_accounts)

  name                      = "subnets-${each.value}"
  allow_external_principals = false

  tags = merge(var.default_tags, {
    Name = "subnets-${each.value}"
  })
}

# RAM Resource Association - Associate subnets with their respective resource shares
resource "aws_ram_resource_association" "subnet_share" {
  for_each = {
    for subnet_key, subnet in local.shared_subnets : subnet.id => {
      account_id = tostring(local.spoke_networks_config[subnet.vpc_name].account)
      subnet_arn = subnet.arn
      subnet_key = subnet_key
    }
  }

  resource_arn       = each.value.subnet_arn
  resource_share_arn = aws_ram_resource_share.cross_account_subnets[each.value.account_id].arn

  depends_on = [aws_ram_resource_share.cross_account_subnets]
}

# RAM Principal Association - Invite target accounts
resource "aws_ram_principal_association" "account_invitation" {
  for_each = toset(local.ram_sharing_accounts)

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.cross_account_subnets[each.value].arn

  depends_on = [aws_ram_resource_share.cross_account_subnets]
}

# Cross-account VPC tagging
resource "aws_ec2_tag" "vpc_name_tags" {
  for_each = local.vpcs

  provider    = aws.principal_account[tostring(local.spoke_networks_config[each.key].account)]
  resource_id = each.value.id
  key         = "Name"
  value       = each.key

  depends_on = [
    aws_ram_principal_association.account_invitation,
    aws_ram_resource_association.subnet_share
  ]
}

# Cross-account subnet tagging
resource "aws_ec2_tag" "subnet_name_tags" {
  for_each = {
    for subnet_key, subnet in local.shared_subnets : subnet.id => {
      account_id           = tostring(local.spoke_networks_config[subnet.vpc_name].account)
      subnet_id            = subnet.id
      subnet_name          = subnet.subnet_name
      availability_zone_id = subnet.availability_zone_id
      vpc_name             = subnet.vpc_name
    }
  }

  provider    = aws.principal_account[each.value.account_id]
  resource_id = each.value.subnet_id
  key         = "Name"
  value       = "${each.value.vpc_name}-${each.value.subnet_name}-${each.value.availability_zone_id}"

  depends_on = [
    aws_ram_principal_association.account_invitation,
    aws_ram_resource_association.subnet_share
  ]
}

# Cross-account route table tagging
resource "aws_ec2_tag" "route_table_name_tags" {
  for_each = {
    for subnet_key, subnet in local.shared_subnets : subnet.id => {
      account_id           = tostring(local.spoke_networks_config[subnet.vpc_name].account)
      route_table_id       = local.subnet_route_tables[subnet_key].id
      subnet_name          = subnet.subnet_name
      availability_zone_id = subnet.availability_zone_id
      vpc_name             = subnet.vpc_name
    }
    if contains(keys(local.subnet_route_tables), subnet_key)
  }

  provider    = aws.principal_account[each.value.account_id]
  resource_id = each.value.route_table_id
  key         = "Name"
  value       = "${each.value.vpc_name}-${each.value.subnet_name}-${each.value.availability_zone_id}-rt"

  depends_on = [
    aws_ram_principal_association.account_invitation,
    aws_ram_resource_association.subnet_share
  ]
}
