# Gateway Load Balancer firewall implementation

resource "aws_lb" "gateway_load_balancer" {
  count                            = local.is_gateway_load_balancer ? 1 : 0
  name                             = "${var.vpc_name}-glb-${random_id.firewall_suffix.hex}"
  load_balancer_type               = "gateway"
  enable_cross_zone_load_balancing = true

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnets
    content {
      subnet_id = subnet_mapping.value.subnet_id
    }
  }

  tags = merge(var.vpc_tags, {
    Name = "${var.vpc_name}-glb-${random_id.firewall_suffix.hex}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group for GWLB
resource "aws_lb_target_group" "gateway_load_balancer" {
  count    = local.is_gateway_load_balancer ? 1 : 0
  name     = "${var.vpc_name}-tg-${random_id.firewall_suffix.hex}"
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 10
    path                = "/health"
    port                = "80"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.vpc_tags, {
    Name = "${var.vpc_name}-tg-${random_id.firewall_suffix.hex}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Attach target group to GWLB
resource "aws_lb_listener" "gateway_load_balancer" {
  count             = local.is_gateway_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.gateway_load_balancer[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway_load_balancer[0].arn
  }

  tags = merge(var.vpc_tags, {
    Name = "${var.vpc_name}-listener-${random_id.firewall_suffix.hex}"
  })
}

# VPC Endpoint Service for GWLB
resource "aws_vpc_endpoint_service" "gateway_load_balancer" {
  count                      = local.is_gateway_load_balancer ? 1 : 0
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gateway_load_balancer[0].arn]

  allowed_principals = [
    "arn:aws:iam::${var.network_account_id}:root"
  ]

  tags = merge(var.vpc_tags, {
    Name = "${var.vpc_name}-endpoint-svc-${random_id.firewall_suffix.hex}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoints in hub firewall subnets
resource "aws_vpc_endpoint" "gateway_load_balancer_hub" {
  count             = local.is_gateway_load_balancer ? length(var.firewall_subnets) : 0
  vpc_id            = var.vpc_id
  service_name      = aws_vpc_endpoint_service.gateway_load_balancer[0].service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [values(var.firewall_subnets)[count.index].subnet_id]

  tags = merge(var.vpc_tags, {
    Name = "${var.vpc_name}-ep-${values(var.firewall_subnets)[count.index].availability_zone_id}-${random_id.firewall_suffix.hex}"
  })

  lifecycle {
    create_before_destroy = true
  }
}
