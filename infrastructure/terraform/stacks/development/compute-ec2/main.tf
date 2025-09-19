data "aws_ssm_parameter" "ubuntu_ami" {
  # Canonical's public SSM parameter for Ubuntu 24.04 LTS (amd64, hvm, ebs-gp3)
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_region" "current" {}

locals {
  name_prefix        = "aws-lab-java-${var.environment}"
  instance_name      = "${local.name_prefix}-ec2-app"
  container_port     = 8080
  vpc_id             = data.terraform_remote_state.core_networking.outputs.vpc_id
  private_subnet_ids = keys(data.terraform_remote_state.core_networking.outputs.private_subnets)
  public_subnet_ids  = keys(data.terraform_remote_state.core_networking.outputs.public_subnets)
  security_groups    = data.terraform_remote_state.core_networking.outputs.security_group_ids
  ecr_repository_url = data.terraform_remote_state.container_registry.outputs.ecr_repository_url
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = "t3.small"
  subnet_id                   = local.private_subnet_ids[0]
  iam_instance_profile        = data.terraform_remote_state.security.outputs.ec2_instance_profile_name
  vpc_security_group_ids      = [local.security_groups.ec2]
  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              REGION="${data.aws_region.current.name}"
              ARCH="amd64"
              PKG_URL="https://s3.${data.aws_region.current.name}.amazonaws.com/amazon-ssm-${data.aws_region.current.name}/latest/debian_${ARCH}/amazon-ssm-agent.deb"
              for i in $(seq 1 10); do
                if curl -fSL -o /tmp/amazon-ssm-agent.deb "$PKG_URL"; then
                  dpkg -i /tmp/amazon-ssm-agent.deb || apt-get update -y && apt-get install -y /tmp/amazon-ssm-agent.deb || true
                  systemctl enable amazon-ssm-agent || true
                  systemctl restart amazon-ssm-agent || systemctl start amazon-ssm-agent || true
                  break
                fi
                sleep 10
              done

              # Install Docker (official repo) and AWS CLI v2
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg unzip
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              chmod a+r /etc/apt/keyrings/docker.gpg
              echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              systemctl enable --now docker

              # AWS CLI v2
              tmpdir=$(mktemp -d) && cd "$tmpdir"
              curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
              unzip -q awscliv2.zip
              ./aws/install || true
              /usr/local/bin/aws --version || true
              EOF

  tags = merge(local.base_tags, {
    Name = local.instance_name
  })
}

resource "aws_lb_target_group" "ec2_service" {
  name        = "${local.name_prefix}-ec2"
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = local.vpc_id

  health_check {
    path                = "/actuator/health"
    matcher             = "200-299"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb_target_group_attachment" "ec2_service" {
  target_group_arn = aws_lb_target_group.ec2_service.arn
  target_id        = aws_instance.app.id
  port             = local.container_port
}

resource "aws_lb_listener_rule" "ec2_service" {
  listener_arn = data.terraform_remote_state.ecs_alb.outputs.alb_https_listener_arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_service.arn
  }

  condition {
    host_header {
      values = [var.ec2_service_domain_name]
    }
  }
}
