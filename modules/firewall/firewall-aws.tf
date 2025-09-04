# AWS Network Firewall implementation

# Note: This provides only the infrastructure. Security rules should be managed separately.
resource "aws_networkfirewall_firewall_policy" "firewall_policy" {
  count = local.is_aws_network_firewall ? 1 : 0
  name  = "${var.vpc_name}-firewall-policy-${random_id.firewall_suffix.hex}"

  firewall_policy {
    # Default action: forward all traffic to stateful engine, then allow
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_default_actions = [var.aws_network_firewall_allow_all ? "aws:alert_strict" : "aws:drop_strict"]
    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(var.vpc_tags, {
    Name = "${var.vpc_name}-firewall-policy-${random_id.firewall_suffix.hex}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Network Firewall
resource "aws_networkfirewall_firewall" "network_firewall" {
  count               = local.is_aws_network_firewall ? 1 : 0
  name                = "${var.vpc_name}-firewall-${random_id.firewall_suffix.hex}"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.firewall_policy[0].arn
  vpc_id              = var.vpc_id

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnets
    content {
      subnet_id = subnet_mapping.value.subnet_id
    }
  }

  tags = merge(var.vpc_tags, {
    Name = "${var.vpc_name}-firewall-${random_id.firewall_suffix.hex}"
  })

  lifecycle {
    create_before_destroy = true
  }
}
