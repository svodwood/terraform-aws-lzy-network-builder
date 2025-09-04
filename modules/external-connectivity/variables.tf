variable "external_connectivity_cidr" {
  description = "CIDR block for the external connectivity VPC"
  type        = string
}

variable "relay_subnet_suffix" {
  description = "CIDR suffix for external connectivity relay subnets"
  type        = number

  validation {
    condition     = var.relay_subnet_suffix >= 16 && var.relay_subnet_suffix <= 30
    error_message = "The relay_subnet_suffix must be between 16 and 30."
  }
}

variable "endpoints_subnet_suffix" {
  description = "CIDR suffix for external connectivity endpoints subnets"
  type        = number

  validation {
    condition     = var.endpoints_subnet_suffix >= 16 && var.endpoints_subnet_suffix <= 30
    error_message = "The endpoints_subnet_suffix must be between 16 and 30."
  }
}

variable "network_account_id" {
  description = "AWS Account ID where the external connectivity VPC will be created"
  type        = string
}

variable "region" {
  description = "AWS region for service name construction"
  type        = string
}

variable "spoke_connectivity_transit_gateway" {
  description = "Spoke Connectivity Transit Gateway object"
  type = object({
    id  = string
    arn = string
  })
}

variable "spoke_connectivity_transit_gateway_attachment" {
  description = "Spoke Connectivity Transit Gateway VPC attachment"
  type = object({
    id = string
  })
}

variable "hub_firewall_route_table" {
  description = "Hub Transit Gateway firewall route table"
  type = object({
    id = string
  })
}

variable "hub_internal_transit_gateway" {
  description = "Hub Internal Transit Gateway object"
  type = object({
    id  = string
    arn = string
  })
}

variable "hub_vpc_cidr" {
  description = "CIDR block for the hub VPC (for routing from endpoints subnets)"
  type        = string
}

variable "availability_zone_ids" {
  description = "List of availability zone IDs to use (must match hub VPC)"
  type        = list(string)
}

variable "vpc_endpoints_config" {
  description = "VPC endpoints configuration from hub config"
  type        = map(any)
  default     = {}
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "LZYNetworkBuilder"
  }
}
