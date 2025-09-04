locals {
  is_aws_firewall  = var.firewall_type == "aws_network_firewall"
  is_gwlb_firewall = var.firewall_type == "gateway_load_balancer"

  # Parse spoke networks configuration
  spoke_networks_config = var.spokes_definition != "" ? yamldecode(file(var.spokes_definition)) : null
}
