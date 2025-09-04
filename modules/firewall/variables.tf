variable "vpc_id" {
  description = "VPC ID where the firewall will be deployed"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC for resource naming"
  type        = string
}

variable "network_account_id" {
  description = "AWS Account ID where all VPCs are created"
  type        = string
}

variable "firewall_type" {
  description = "Type of firewall deployment to use"
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

variable "firewall_subnets" {
  description = "Map of firewall subnets where endpoints will be deployed"
  type = map(object({
    subnet_id            = string
    availability_zone_id = string
    vpc_name             = string
  }))
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "OpenTofu"
    Project   = "LZYNetworkBuilder"
  }
}

variable "vpc_tags" {
  description = "Tags from the VPC for inheritance"
  type        = map(string)
  default     = {}
}

variable "aws_network_firewall_allow_all" {
  description = "When true, configures AWS Network Firewall to allow all traffic instead of drop strict"
  type        = bool
  default     = false
}
