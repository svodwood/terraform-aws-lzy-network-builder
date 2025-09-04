# VPC Foundation Module - Core Mathematical Functions
# Provides subnet allocation, space validation, and CIDR calculation logic

locals {
  # Extract VPC prefix 
  vpc_prefix = tonumber(split("/", var.vpc_config.cidr)[1])
  vpc_name   = var.vpc_config.name

  # Determine which technical subnets to create for this VPC
  vpc_technical_subnets = {
    for subnet_name, subnet_config in var.technical_subnets :
    subnet_name => subnet_config
    if(
      contains(subnet_config.create_for, "all") ||
      contains(subnet_config.create_for, var.vpc_config.type) ||
      contains(subnet_config.create_for, var.module_type) ||
      contains(subnet_config.create_for, var.vpc_config.name)
    )
  }

  # Calculate subnet space requirements
  user_space = length(var.vpc_config.subnets) > 0 ? sum([
    for subnet_name, subnet_suffix in var.vpc_config.subnets :
    pow(2, 32 - subnet_suffix) * length(var.vpc_config.availability_zone_ids)
  ]) : 0

  # Technical subnet space calculation  
  technical_space = sum([
    for subnet_name, subnet_config in local.vpc_technical_subnets :
    pow(2, 32 - subnet_config.suffix) * length(var.vpc_config.availability_zone_ids)
  ])

  # Public endpoints space calculation
  public_endpoints_space = (
    var.vpc_config.type == "public" && var.vpc_config.public_endpoints_size != null ?
    pow(2, 32 - var.vpc_config.public_endpoints_size) * length(var.vpc_config.availability_zone_ids) :
    0
  )

  # Total space requirement
  total_space = local.user_space + local.technical_space + local.public_endpoints_space

  # Calculate space requirements for the VPC
  vpc_space_calculation = {
    vpc_size               = pow(2, 32 - local.vpc_prefix)
    user_subnet_space      = local.user_space
    technical_subnet_space = local.technical_space
    public_endpoints_space = local.public_endpoints_space
    total_required_space   = local.total_space
    available_space        = pow(2, 32 - local.vpc_prefix) - local.total_space
    utilization_percent    = floor((local.total_space / pow(2, 32 - local.vpc_prefix)) * 100)
    is_valid               = local.total_space <= pow(2, 32 - local.vpc_prefix)
  }

  # Calculate subnet offsets for user-defined subnets (allocated from beginning of VPC)
  subnet_offsets = {
    for i, subnet_name in keys(var.vpc_config.subnets) : subnet_name =>
    # Sum space used by all previous subnet types
    i == 0 ? 0 : sum([
      for j in range(i) :
      # Use consistent calculation pattern
      pow(2, 32 - var.vpc_config.subnets[keys(var.vpc_config.subnets)[j]]) * length(var.vpc_config.availability_zone_ids)
    ]) / pow(2, 32 - var.vpc_config.subnets[subnet_name])
  }

  # Calculate end positions for technical subnets (allocated from end of VPC)
  # Sort by suffix size (smaller suffix = larger subnet) to allocate largest subnets first
  technical_subnet_sorted_keys = [
    for key_pair in sort([
      for k, v in local.vpc_technical_subnets : "${format("%02d", v.suffix)}:${k}"
    ]) : split(":", key_pair)[1]
  ]

  # Calculate raw end positions (may be negative if insufficient space)
  technical_subnet_end_positions_raw = {
    for i, subnet_name in local.technical_subnet_sorted_keys : subnet_name => (
      pow(2, local.vpc_technical_subnets[subnet_name].suffix - local.vpc_prefix) -
      # Account for space used by technical subnets that come after this one (sorted by size)
      sum([
        for j in range(length(local.technical_subnet_sorted_keys)) :
        j > i ? ceil(
          (pow(2, 32 - local.vpc_technical_subnets[local.technical_subnet_sorted_keys[j]].suffix) *
          length(var.vpc_config.availability_zone_ids)) /
          pow(2, 32 - local.vpc_technical_subnets[subnet_name].suffix)
        ) : 0
      ]) -
      # Reserve space for the AZs of this subnet itself
      length(var.vpc_config.availability_zone_ids)
    )
  }

  # Safe end positions - prevent negative values that would break cidrsubnet()
  technical_subnet_end_positions = {
    for subnet_name, raw_position in local.technical_subnet_end_positions_raw :
    subnet_name => max(0, raw_position)
  }

  # Generate complete subnet configurations
  subnet_configurations = merge(
    # User-defined subnets (allocated from beginning of VPC address space)
    {
      for subnet_name, subnet_suffix in var.vpc_config.subnets :
      "${local.vpc_name}-${replace(cidrsubnet(var.vpc_config.cidr, subnet_suffix - local.vpc_prefix, local.subnet_offsets[subnet_name]), "/", "-")}" => {
        vpc_name      = local.vpc_name
        subnet_name   = subnet_name
        subnet_type   = "user-defined"
        vpc_cidr      = var.vpc_config.cidr
        subnet_suffix = subnet_suffix
        azs_count     = length(var.vpc_config.availability_zone_ids)
        account       = var.vpc_config.account
        type          = var.vpc_config.type
        risk          = var.vpc_config.risk
        is_shared     = false # User subnets sharing determined by calling module

        # Standard subnet attributes
        is_technical = false
        is_user      = true

        # Calculate subnet CIDRs for each AZ using offsets
        subnet_cidrs = [
          for az_index in range(length(var.vpc_config.availability_zone_ids)) :
          cidrsubnet(
            var.vpc_config.cidr,
            subnet_suffix - local.vpc_prefix,
            local.subnet_offsets[subnet_name] + az_index
          )
        ]

        # Map AZ IDs to subnet CIDRs
        az_subnets = {
          for az_index in range(length(var.vpc_config.availability_zone_ids)) :
          var.vpc_config.availability_zone_ids[az_index] => cidrsubnet(
            var.vpc_config.cidr,
            subnet_suffix - local.vpc_prefix,
            local.subnet_offsets[subnet_name] + az_index
          )
        }
      }
    },

    # Technical subnets (allocated from end of VPC address space)
    {
      for subnet_name, subnet_config in local.vpc_technical_subnets :
      "${local.vpc_name}-${replace(cidrsubnet(var.vpc_config.cidr, subnet_config.suffix - local.vpc_prefix, local.technical_subnet_end_positions[subnet_name]), "/", "-")}" => {
        vpc_name      = local.vpc_name
        subnet_name   = subnet_name
        subnet_type   = "technical"
        vpc_cidr      = var.vpc_config.cidr
        subnet_suffix = subnet_config.suffix
        azs_count     = length(var.vpc_config.availability_zone_ids)
        account       = var.vpc_config.account
        type          = var.vpc_config.type
        risk          = var.vpc_config.risk
        is_shared     = subnet_config.is_shared

        # Standard subnet attributes
        is_technical = true
        is_user      = false

        # Use technical subnet attributes as provided
        attributes = subnet_config.attributes

        # Calculate technical subnet CIDRs from END of VPC address space
        subnet_cidrs = [
          for az_index in range(length(var.vpc_config.availability_zone_ids)) :
          cidrsubnet(
            var.vpc_config.cidr,
            subnet_config.suffix - local.vpc_prefix,
            # Calculate position from end, accounting for other technical subnets
            local.technical_subnet_end_positions[subnet_name] + az_index
          )
        ]

        # Map AZ IDs to subnet CIDRs
        az_subnets = {
          for az_index in range(length(var.vpc_config.availability_zone_ids)) :
          var.vpc_config.availability_zone_ids[az_index] => cidrsubnet(
            var.vpc_config.cidr,
            subnet_config.suffix - local.vpc_prefix,
            local.technical_subnet_end_positions[subnet_name] + az_index
          )
        }
      }
    }
  )

  # Helper for default technical subnet attributes
  default_technical_attributes = {
    is_firewall         = false
    is_egress           = false
    is_relay            = false
    is_inspection       = false
    is_public_endpoints = false
    is_shared_endpoints = false
  }

  # Flatten subnet resources for easy consumption by calling modules
  subnet_resources = merge([
    for subnet_key, subnet_config in local.subnet_configurations : {
      for az_id, cidr in subnet_config.az_subnets :
      "${subnet_key}-${az_id}" => merge(
        subnet_config,
        local.default_technical_attributes,
        try(subnet_config.attributes, {}),
        {
          subnet_key           = subnet_key
          availability_zone_id = az_id
          cidr_block           = cidr
          is_technical         = subnet_config.is_technical
          is_user              = subnet_config.is_user
        }
      )
    }
  ]...)

  # Validation errors for space issues
  space_validation_error = local.vpc_space_calculation.is_valid ? null : "VPC ${local.vpc_name} (${var.vpc_config.cidr}) has insufficient space. Required: ${local.vpc_space_calculation.total_required_space} IPs, Available: ${local.vpc_space_calculation.vpc_size} IPs"

  # Validation errors for technical subnet allocation
  technical_subnet_allocation_errors = [
    for subnet_name, raw_position in local.technical_subnet_end_positions_raw :
    "VPC ${local.vpc_name}: Technical subnet '${subnet_name}' cannot be allocated (insufficient space). Raw position: ${raw_position}"
    if raw_position < 0
  ]

  # Validation errors for public VPC configuration
  public_vpc_validation_error = (
    var.vpc_config.type == "public" && var.vpc_config.public_endpoints_size == null ?
    "VPC ${local.vpc_name} has type 'public' but missing required 'public_endpoints_size' field" :
    null
  )

  # Validation errors for private VPC configuration
  private_vpc_validation_error = (
    var.vpc_config.type == "private" && var.vpc_config.public_endpoints_size != null ?
    "VPC ${local.vpc_name} has type 'private' but 'public_endpoints_size' field is not allowed for private VPCs" :
    null
  )

  # Combined validation errors
  all_validation_errors = compact([
    local.space_validation_error,
    local.public_vpc_validation_error,
    local.private_vpc_validation_error
  ])

  validation_errors = concat(
    local.all_validation_errors,
    local.technical_subnet_allocation_errors
  )
}
