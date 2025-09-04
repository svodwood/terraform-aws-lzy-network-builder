# VPC Foundation Module Variables
# This module provides shared mathematical functions for subnet allocation and validation

variable "vpc_config" {
  description = "Single VPC configuration with subnets and metadata"
  type = object({
    name                  = string
    cidr                  = string
    availability_zone_ids = list(string)
    subnets               = map(number) # subnet_name => suffix
    account               = optional(string)
    type                  = optional(string, "private")
    risk                  = optional(string)
    tags                  = optional(map(string), {})
    # Public VPC specific fields
    public_endpoints_size = optional(number)
  })

  validation {
    condition     = can(cidrhost(var.vpc_config.cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }

  validation {
    condition     = length(var.vpc_config.availability_zone_ids) > 0
    error_message = "VPC must have at least one availability zone."
  }

  validation {
    condition     = var.vpc_config.name != null && var.vpc_config.name != ""
    error_message = "VPC name must be provided."
  }
}

variable "technical_subnets" {
  description = "Configuration for automatically created technical subnets"
  type = map(object({
    suffix     = number
    create_for = list(string)            # ["all", "public", "private", "hub", "spoke"] or specific VPC names
    is_shared  = optional(bool, false)   # Whether subnets are shared via RAM
    attributes = optional(map(bool), {}) # Additional subnet attributes (is_relay, is_firewall, etc.)
  }))
  default = {}

  validation {
    condition = alltrue([
      for subnet_name, config in var.technical_subnets :
      config.suffix >= 16 && config.suffix <= 30
    ])
    error_message = "All technical subnet suffixes must be between 16 and 30."
  }
}

variable "module_type" {
  description = "Type of the calling module (hub, spoke, etc.) for context-specific logic"
  type        = string
  default     = "generic"

  validation {
    condition     = contains(["hub", "spoke", "generic"], var.module_type)
    error_message = "Module type must be one of: hub, spoke, generic."
  }
}
