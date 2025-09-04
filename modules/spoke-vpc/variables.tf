variable "vpc_name" {
  description = "Name of the VPC to create"
  type        = string
}

variable "vpc_config" {
  description = "VPC configuration from YAML"
  type = object({
    account               = string
    type                  = string
    cidr                  = string
    availability_zone_ids = list(string)
    risk                  = optional(string, "medium")
    public_endpoints_size = optional(number)
    subnets               = map(number)
    tags                  = optional(map(string), {})
  })
}

variable "network_account_id" {
  description = "AWS Account ID where all VPCs will be created"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "OpenTofu"
    Project   = "LZYNetworkBuilder"
  }
}

variable "spoke_inspection_subnet_suffix" {
  description = "CIDR suffix for inspection subnets (service subnets for network inspection)"
  type        = number
  default     = 28
}

variable "spoke_relay_subnet_suffix" {
  description = "CIDR suffix for relay subnets (service subnets for network relay)"
  type        = number
  default     = 24
}

variable "spoke_connectivity_transit_gateway" {
  description = "Transit Gateway from hub module to attach principal VPCs to"
  type = object({
    id                                 = string
    arn                                = string
    association_default_route_table_id = string
    propagation_default_route_table_id = string
    vpc_name                           = string
    tags                               = map(string)
  })
  default = null
}

variable "spoke_connectivity_transit_gateway_firewall_route_tables" {
  description = "Transit Gateway firewall route tables from hub module for return traffic routing"
  type = map(object({
    id                 = string
    transit_gateway_id = string
    vpc_name           = string
    tags               = map(string)
  }))
  default = {}
}

variable "spoke_connectivity_transit_gateway_attachments" {
  description = "Transit Gateway attachments from hub module for propagation configuration"
  type = map(object({
    id                 = string
    transit_gateway_id = string
    vpc_id             = string
    vpc_name           = string
    tags               = map(string)
  }))
  default = {}
}

variable "shared_endpoints_profile" {
  description = "Route 53 Resolver profile for sharing VPC endpoints"
  type = object({
    id   = string
    name = string
    tags = map(string)
  })
  default = null
}
