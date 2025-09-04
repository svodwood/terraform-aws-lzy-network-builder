# Data source for latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "web_sg" {
  name_prefix = "web-ec2-sg-"
  description = "Security group for web server EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "All traffic from anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-ec2-sg"
  }
}

# Network Load Balancer
resource "aws_lb" "web_nlb" {
  count              = var.create_nlb ? 1 : 0
  name               = "web-test-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "web-test-nlb"
  }
}

# Target Group for HTTP (Port 80)
resource "aws_lb_target_group" "web_tg_80" {
  count    = var.create_nlb ? 1 : 0
  name     = "web-test-tg-80"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "TCP"
    port                = "80"
  }

  tags = {
    Name = "web-test-tg-80"
  }
}

# Target Group for SSH (Port 22)
resource "aws_lb_target_group" "web_tg_22" {
  count    = var.create_nlb ? 1 : 0
  name     = "web-test-tg-22"
  port     = 22
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "TCP"
    port                = "22"
  }

  tags = {
    Name = "web-test-tg-22"
  }
}

# NLB Listener for HTTP (Port 80)
resource "aws_lb_listener" "web_listener_80" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.web_nlb[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg_80[0].arn
  }
}

# NLB Listener for SSH (Port 22)
resource "aws_lb_listener" "web_listener_22" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.web_nlb[0].arn
  port              = "22"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg_22[0].arn
  }
}

# IAM Role for EC2 instance (for Systems Manager)
resource "aws_iam_role" "ec2_ssm_role" {
  name = "EC2-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "EC2-SSM-Role"
  }
}

# Attach AWS managed policy for Systems Manager
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-SSM-Profile"
  role = aws_iam_role.ec2_ssm_role.name

  tags = {
    Name = "EC2-SSM-Profile"
  }
}

# EC2 Instance
resource "aws_instance" "web_server" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = var.instance_type
  key_name             = "svnettest"
  subnet_id            = var.private_subnet_ids[0]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    # User Data Script for Amazon Linux 2023
    # Installs nginx and creates a default test page

    # Update the system
    dnf update -y

    # Create user ${var.admin_username}
    useradd -m -s /bin/bash ${var.admin_username}
    
    # Add ${var.admin_username} to sudo group (wheel on Amazon Linux)
    usermod -aG wheel ${var.admin_username}
    
    # Configure passwordless sudo for ${var.admin_username}
    echo "${var.admin_username} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${var.admin_username}
    chmod 440 /etc/sudoers.d/${var.admin_username}
    
    # Set up SSH directory and authorized_keys for ${var.admin_username}
    mkdir -p /home/${var.admin_username}/.ssh
    chmod 700 /home/${var.admin_username}/.ssh
    touch /home/${var.admin_username}/.ssh/authorized_keys
    chmod 600 /home/${var.admin_username}/.ssh/authorized_keys
    chown -R ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/.ssh

    # Install nginx
    dnf install -y nginx

    # Start and enable nginx service
    systemctl start nginx
    systemctl enable nginx

    # Create a custom default page
    cat > /usr/share/nginx/html/index.html << 'HTML_EOF'
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Test Server - LZY Network Builder</title>
        <style>
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                margin: 0;
                padding: 0;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .container {
                background: white;
                padding: 2rem;
                border-radius: 10px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.3);
                text-align: center;
                max-width: 600px;
                margin: 20px;
            }
            h1 {
                color: #333;
                margin-bottom: 1rem;
            }
            .status {
                background: #4CAF50;
                color: white;
                padding: 10px 20px;
                border-radius: 5px;
                display: inline-block;
                margin: 10px 0;
            }
            .info {
                background: #f5f5f5;
                padding: 15px;
                border-radius: 5px;
                margin: 15px 0;
                border-left: 4px solid #2196F3;
            }
            .footer {
                margin-top: 20px;
                color: #666;
                font-size: 0.9rem;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 LZY Network Builder Test Server</h1>
            <div class="status">✅ Nginx is running successfully!</div>
            
            <div class="info">
                <h3>Network Test</h3>
                <p>If you can see this page, your network connectivity is working!</p>
                <p>✅ DNS Resolution</p>
                <p>✅ Package Installation (dnf/yum)</p>
                <p>✅ Outbound Internet Access</p>
                <p>✅ Inbound HTTP Access</p>
            </div>
            
            <div class="footer">
                <p>Generated at: <span id="timestamp"></span></p>
                <script>
                    document.getElementById('timestamp').textContent = new Date().toLocaleString();
                </script>
            </div>
        </div>
    </body>
    </html>
    HTML_EOF

    # Set proper permissions
    chown nginx:nginx /usr/share/nginx/html/index.html
    chmod 644 /usr/share/nginx/html/index.html

    # Ensure nginx is running and configured correctly
    systemctl restart nginx

    # Create a simple health check endpoint
    cat > /usr/share/nginx/html/health << 'HEALTH_EOF'
    OK
    HEALTH_EOF

    # Log installation completion
    echo "$(date): Nginx installation and configuration completed successfully" >> /var/log/user-data.log

    # Show status for debugging
    systemctl status nginx >> /var/log/user-data.log 2>&1
    curl -s http://localhost/ >> /var/log/user-data.log 2>&1

    echo "User data script execution completed successfully"
  EOF

  tags = {
    Name = "web-test-server"
  }
}

# Target Group Attachment for HTTP (Port 80)
resource "aws_lb_target_group_attachment" "web_attachment_80" {
  count            = var.create_nlb ? 1 : 0
  target_group_arn = aws_lb_target_group.web_tg_80[0].id
  target_id        = aws_instance.web_server.id
  port             = 80
}

# Target Group Attachment for SSH (Port 22)
resource "aws_lb_target_group_attachment" "web_attachment_22" {
  count            = var.create_nlb ? 1 : 0
  target_group_arn = aws_lb_target_group.web_tg_22[0].id
  target_id        = aws_instance.web_server.id
  port             = 22
}
