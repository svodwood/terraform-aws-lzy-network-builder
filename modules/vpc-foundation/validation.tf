# VPC Foundation Module - Built-in Validation Checks
# These checks will cause plan/apply to fail if configuration issues are detected

# VPC space validation - will cause plan to fail if insufficient space
check "vpc_space_validation" {
  assert {
    condition     = local.space_validation_error == null
    error_message = "VPC space validation failed:\n${coalesce(local.space_validation_error, "Unknown space validation error")}"
  }
}

# Public VPC configuration validation
check "public_vpc_configuration_validation" {
  assert {
    condition     = local.public_vpc_validation_error == null
    error_message = "Public VPC configuration validation failed:\n${coalesce(local.public_vpc_validation_error, "Unknown public VPC configuration error")}"
  }
}

# Private VPC configuration validation
check "private_vpc_configuration_validation" {
  assert {
    condition     = local.private_vpc_validation_error == null
    error_message = "Private VPC configuration validation failed:\n${coalesce(local.private_vpc_validation_error, "Unknown private VPC configuration error")}"
  }
}

# Overall validation check - comprehensive validation
check "comprehensive_validation" {
  assert {
    condition     = length(local.validation_errors) == 0
    error_message = "VPC Foundation validation failed:\n${join("\n", local.validation_errors)}"
  }
}

# Additional validation for subnet suffix consistency
check "subnet_suffix_validation" {
  assert {
    condition = alltrue([
      for subnet_name, subnet_suffix in var.vpc_config.subnets :
      subnet_suffix >= 16 && subnet_suffix <= 30
    ])
    error_message = "All subnet suffixes must be between 16 and 30."
  }
}

# Validation for VPC CIDR consistency
check "vpc_cidr_validation" {
  assert {
    condition     = local.vpc_prefix >= 8 && local.vpc_prefix <= 28
    error_message = "VPC CIDR prefix must be between /8 and /28."
  }
}

# Validation for availability zone requirements
check "availability_zone_validation" {
  assert {
    condition     = length(var.vpc_config.availability_zone_ids) >= 1 && length(var.vpc_config.availability_zone_ids) <= 6
    error_message = "VPC must have between 1 and 6 availability zones."
  }
}

# Validation for risk-based availability zone requirements
check "risk_based_availability_zone_validation" {
  assert {
    condition = (
      (var.vpc_config.risk == "medium" || var.vpc_config.risk == "high") ?
      length(var.vpc_config.availability_zone_ids) >= 2 : true
    )
    error_message = "Medium and high risk VPCs must span a minimum of 2 availability zones. Found VPC with insufficient AZs: ${var.vpc_config.name} (risk: ${var.vpc_config.risk}, AZs: ${length(var.vpc_config.availability_zone_ids)})"
  }
}

# Validation for technical subnet configuration
check "technical_subnet_validation" {
  assert {
    condition = alltrue([
      for subnet_name, subnet_config in var.technical_subnets :
      length(subnet_config.create_for) > 0
    ])
    error_message = "Each technical subnet must specify at least one target in 'create_for'."
  }
}

# Validation for technical subnet space allocation
check "technical_subnet_allocation_validation" {
  assert {
    condition     = length(local.technical_subnet_allocation_errors) == 0
    error_message = "Technical subnet allocation validation failed:\n${join("\n", local.technical_subnet_allocation_errors)}"
  }
}
