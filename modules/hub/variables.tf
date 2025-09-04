variable "hub_definition" {
  description = "Path to the regional YAML file containing hub VPC definition"
  type        = string
}

variable "region" {
  description = "AWS region for service name construction"
  type        = string
}

variable "network_account_id" {
  description = "AWS Account ID where the hub VPC will be created"
  type        = string
}

variable "hub_relay_subnet_suffix" {
  description = "CIDR suffix for hub relay subnets"
  type        = number
  default     = 24

  validation {
    condition     = var.hub_relay_subnet_suffix >= 16 && var.hub_relay_subnet_suffix <= 30
    error_message = "The hub_relay_subnet_suffix must be between 16 and 30."
  }
}

variable "hub_firewall_subnet_suffix" {
  description = "CIDR suffix for hub firewall subnets"
  type        = number
  default     = 28

  validation {
    condition     = var.hub_firewall_subnet_suffix >= 16 && var.hub_firewall_subnet_suffix <= 30
    error_message = "The hub_firewall_subnet_suffix must be between 16 and 30."
  }
}

variable "hub_egress_subnet_suffix" {
  description = "CIDR suffix for hub egress subnets"
  type        = number
  default     = 24

  validation {
    condition     = var.hub_egress_subnet_suffix >= 16 && var.hub_egress_subnet_suffix <= 30
    error_message = "The hub_egress_subnet_suffix must be between 16 and 30."
  }
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "OpenTofu"
    Project   = "LZYNetworkBuilder"
  }
}

variable "external_connectivity_cidr" {
  description = "CIDR block for external connectivity VPC (for routing hub user-defined subnets)"
  type        = string
}
