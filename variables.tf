variable "network_account_id" {
  description = "AWS Account ID where all VPCs will be created"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.network_account_id))
    error_message = "The network_account_id must be a 12-digit AWS account ID."
  }
}

variable "network_account_profile" {
  description = "AWS profile name for the network account"
  type        = string
  default     = "network-account"
}

variable "spokes_definition" {
  description = "Path to the YAML file containing spoke VPC network definitions (e.g., 'configs/spokes.yaml')"
  type        = string
  default     = ""

  validation {
    condition     = var.spokes_definition == "" || can(regex("\\.ya?ml$", var.spokes_definition))
    error_message = "The spokes_definition must be a YAML file (with .yaml or .yml extension) or empty string."
  }
}

variable "hub_definition" {
  description = "Path to the YAML file containing hub VPC network definition (e.g., 'configs/hub.yaml')"
  type        = string

  validation {
    condition     = can(regex("\\.ya?ml$", var.hub_definition))
    error_message = "The hub_definition must be a YAML file (with .yaml or .yml extension)."
  }
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "LZYNetworkBuilder"
  }
}

variable "spoke_inspection_subnet_suffix" {
  description = "CIDR suffix for inspection subnets (service subnets for network inspection)"
  type        = number
  default     = 28

  validation {
    condition     = var.spoke_inspection_subnet_suffix >= 16 && var.spoke_inspection_subnet_suffix <= 30
    error_message = "The spoke_inspection_subnet_suffix must be between 16 and 30."
  }
}

variable "spoke_relay_subnet_suffix" {
  description = "CIDR suffix for relay subnets (service subnets for network relay)"
  type        = number
  default     = 28

  validation {
    condition     = var.spoke_relay_subnet_suffix >= 16 && var.spoke_relay_subnet_suffix <= 30
    error_message = "The spoke_relay_subnet_suffix must be between 16 and 30."
  }
}

variable "hub_relay_subnet_suffix" {
  description = "CIDR suffix for hub relay subnets"
  type        = number
  default     = 28

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
  default     = 26

  validation {
    condition     = var.hub_egress_subnet_suffix >= 16 && var.hub_egress_subnet_suffix <= 30
    error_message = "The hub_egress_subnet_suffix must be between 16 and 30."
  }
}

variable "firewall_type" {
  description = "Type of firewall deployment to use in hub VPCs"
  type        = string
  default     = "aws_network_firewall"

  validation {
    condition = contains([
      "aws_network_firewall",
      "gateway_load_balancer"
    ], var.firewall_type)
    error_message = "Firewall type must be one of: aws_network_firewall, gateway_load_balancer"
  }
}

variable "aws_network_firewall_allow_all" {
  description = "When true, configures AWS Network Firewall to allow all traffic instead of drop strict"
  type        = bool
  default     = false
}

variable "external_connectivity_cidr" {
  description = "CIDR block for the external connectivity VPC"
  type        = string
  default     = "100.65.0.0/20"

  validation {
    condition     = can(cidrhost(var.external_connectivity_cidr, 0))
    error_message = "The external_connectivity_cidr must be a valid CIDR block."
  }
}

variable "external_connectivity_relay_subnet_suffix" {
  description = "CIDR suffix for external connectivity relay subnets"
  type        = number
  default     = 28

  validation {
    condition     = var.external_connectivity_relay_subnet_suffix >= 16 && var.external_connectivity_relay_subnet_suffix <= 30
    error_message = "The external_connectivity_relay_subnet_suffix must be between 16 and 30."
  }
}

variable "external_connectivity_endpoints_subnet_suffix" {
  description = "CIDR suffix for external connectivity endpoints subnets"
  type        = number
  default     = 24

  validation {
    condition     = var.external_connectivity_endpoints_subnet_suffix >= 16 && var.external_connectivity_endpoints_subnet_suffix <= 30
    error_message = "The external_connectivity_endpoints_subnet_suffix must be between 16 and 30."
  }
}
