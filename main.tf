/*
================================================================================
TERRAFORM VERSION MANAGEMENT GUIDE
================================================================================
This configuration requires Terraform v1.5.7. Follow these steps to set up tfenv
(version manager) and troubleshoot common issues.

1. INSTALL TFENV (TERRAFORM VERSION MANAGER)
--------------------------------------------
Run these commands in your AWS CloudShell or local environment:

# Install prerequisites (git, make)
sudo yum install -y git make

# Clone tfenv repository
git clone https://github.com/tfutils/tfenv.git ~/.tfenv

# Add tfenv to PATH
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
tfenv --version

2. INSTALL TERRAFORM 1.5.7
--------------------------
# Install specific version (matches main.tf requirement)
tfenv install 1.5.7
tfenv use 1.5.7

# Verify version
terraform -v  # Should show "Terraform v1.5.7"

3. TROUBLESHOOTING (TSHOOT)
---------------------------
Issue: 'tfenv' not recognized after CloudShell restart
Fix: Re-run PATH setup:
     export PATH="$HOME/.tfenv/bin:$PATH"

Issue: Permission errors
Fix: Ensure execute permissions:
     chmod +x ~/.tfenv/bin/*

Issue: Terraform version mismatch
Fix: Force version:
     tfenv use 1.5.7 --force
	 
4. CHANGE THE KEY NAME AND GIT REPOSITORY
-----------------------------------------
- Key_name in use cctb-main, you can create one with this name before run the script
- Replace the git clone with your own.

5. TERRAFORM COMMANDS
---------------------
terraform init
terraform plan
terraform apply
terraform destroy

===================
*/
terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Main VPC"
  }
}

# Public Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet A"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet B"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main IGW"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# AMI Data Source
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group
resource "aws_security_group" "web" {
  name        = "web-server-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web Server Security Group"
  }
}

# Launch Template with Git clone functionality
resource "aws_launch_template" "web" {
  name_prefix   = "web-server-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = "cctb-main"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Update system and install required packages
              sudo yum update -y
              sudo amazon-linux-extras install epel -y
              sudo yum install -y httpd git stress curl
              
              # Start and enable Apache
              sudo systemctl start httpd
              sudo systemctl enable httpd
              
              # Clone your repository
              sudo git clone https://github.com/sbzsilva/IST101G1-S2-Midterm-sergio.git /tmp/ist101-repo
              
              # Remove existing content and move new content
              sudo rm -rf /var/www/html/*
              sudo mv /tmp/ist101-repo/* /var/www/html/
              
              # Clean up
              sudo rm -rf /tmp/ist101-repo
              
              # Ensure proper permissions
              sudo chown -R apache:apache /var/www/html
              sudo chmod -R 755 /var/www/html
              
              # Get instance metadata
              INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
              PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
              
              # Create a simple API endpoint for our instance info
              echo "{\"instanceId\":\"$INSTANCE_ID\",\"publicIp\":\"$PUBLIC_IP\"}" | sudo tee /var/www/html/instance.json > /dev/null
              
              # Restart Apache to apply changes
              sudo systemctl restart httpd
              EOF
              )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Web Server"
    }
  }
}

# Load Balancer
resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "Web ALB"
  }
}

# Target Group
resource "aws_lb_target_group" "web" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  tags = {
    Name = "Web Target Group"
  }
}

# Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name_prefix          = "web-asg-"
  vpc_zone_identifier  = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  min_size             = 1
  max_size             = 7
  desired_capacity     = 1
  health_check_type    = "ELB"
  target_group_arns    = [aws_lb_target_group.web.arn]
  termination_policies = ["OldestInstance"]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "Web Server"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy
resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 35.0
  }
}

# Outputs
output "load_balancer_dns" {
  value       = aws_lb.web.dns_name
  description = "The DNS name of the load balancer"
}

output "target_group_arn" {
  value       = aws_lb_target_group.web.arn
  description = "ARN of the target group"
}