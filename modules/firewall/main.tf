# Firewall module with strategy pattern for different firewall types

locals {
  is_aws_network_firewall  = var.firewall_type == "aws_network_firewall"
  is_gateway_load_balancer = var.firewall_type == "gateway_load_balancer"
}

resource "random_id" "firewall_suffix" {
  byte_length = 4

  keepers = {
    vpc_name      = var.vpc_name
    firewall_type = var.firewall_type
  }
}
