# Validation locals

locals {
  # Collect validation errors from all modules
  vpc_validation_errors = concat(
    flatten([
      for vpc_name, vpc_module in module.spoke_vpc : vpc_module.validation_errors
    ]),
    module.hub.validation_errors
  )
}

# VPC space validation - will cause plan to fail if insufficient space
check "vpc_space_validation" {
  assert {
    condition     = length(local.vpc_validation_errors) == 0
    error_message = "VPC space validation failed:\n${join("\n", local.vpc_validation_errors)}"
  }
}
