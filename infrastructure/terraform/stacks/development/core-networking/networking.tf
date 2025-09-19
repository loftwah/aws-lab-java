data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "shared" {
  id = var.vpc_id
}

data "aws_subnet" "public" {
  for_each = toset(var.public_subnet_ids)
  id       = each.value
}

data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

locals {
  subnet_az_map = {
    public  = { for id, subnet in data.aws_subnet.public : id => subnet.availability_zone }
    private = { for id, subnet in data.aws_subnet.private : id => subnet.availability_zone }
  }

  sg_name_prefix = "aws-lab-java-${var.environment}"
}

resource "aws_security_group" "alb" {
  name        = "${local.sg_name_prefix}-alb"
  description = "Ingress security group for the application load balancers"
  vpc_id      = data.aws_vpc.shared.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow outbound traffic to application targets"
  }

  tags = merge(local.base_tags, {
    Component = "alb"
  })
}

resource "aws_security_group" "ecs_service" {
  name        = "${local.sg_name_prefix}-ecs"
  description = "Security group for ECS application tasks"
  vpc_id      = data.aws_vpc.shared.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow outbound access to dependencies"
  }

  tags = merge(local.base_tags, {
    Component = "ecs-service"
  })
}

resource "aws_security_group" "ec2_service" {
  name        = "${local.sg_name_prefix}-ec2"
  description = "Security group for EC2-based application instances"
  vpc_id      = data.aws_vpc.shared.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow outbound access to dependencies"
  }

  tags = merge(local.base_tags, {
    Component = "ec2-service"
  })
}

resource "aws_security_group" "database" {
  name        = "${local.sg_name_prefix}-database"
  description = "Security group for the shared PostgreSQL database"
  vpc_id      = data.aws_vpc.shared.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow outbound for monitoring and backups"
  }

  tags = merge(local.base_tags, {
    Component = "database"
  })
}

resource "aws_security_group" "bastion" {
  name        = "${local.sg_name_prefix}-bastion"
  description = "Security group for bastion/management access via SSM"
  vpc_id      = data.aws_vpc.shared.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow managed outbound access"
  }

  tags = merge(local.base_tags, {
    Component = "bastion"
  })
}

# ALB ingress from the internet
resource "aws_security_group_rule" "alb_http_ingress" {
  description       = "Allow HTTP"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_https_ingress" {
  description       = "Allow HTTPS"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.alb.id
}

# Application ingress from ALB to ECS/EC2 services
resource "aws_security_group_rule" "ecs_from_alb" {
  description              = "Allow ALB to reach ECS tasks"
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_service.id
}

resource "aws_security_group_rule" "ec2_from_alb" {
  description              = "Allow ALB to reach EC2 instances"
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ec2_service.id
}

# Database ingress from application tiers and bastion
resource "aws_security_group_rule" "database_from_ecs" {
  description              = "Allow ECS tasks to reach PostgreSQL"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_service.id
  security_group_id        = aws_security_group.database.id
}

resource "aws_security_group_rule" "database_from_ec2" {
  description              = "Allow EC2 service to reach PostgreSQL"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_service.id
  security_group_id        = aws_security_group.database.id
}

resource "aws_security_group_rule" "database_from_bastion" {
  description              = "Allow bastion diagnostics to reach PostgreSQL"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.database.id
}

output "security_group_ids" {
  description = "Map of shared security groups for downstream stacks"
  value = {
    alb      = aws_security_group.alb.id
    ecs      = aws_security_group.ecs_service.id
    ec2      = aws_security_group.ec2_service.id
    database = aws_security_group.database.id
    bastion  = aws_security_group.bastion.id
  }
}

output "vpc_id" {
  description = "VPC identifier reused by the environment"
  value       = data.aws_vpc.shared.id
}

output "public_subnets" {
  description = "Public subnet IDs with AZ metadata"
  value = {
    for id, subnet in data.aws_subnet.public : id => {
      availability_zone = subnet.availability_zone
      cidr_block        = subnet.cidr_block
    }
  }
}

output "private_subnets" {
  description = "Private subnet IDs with AZ metadata"
  value = {
    for id, subnet in data.aws_subnet.private : id => {
      availability_zone = subnet.availability_zone
      cidr_block        = subnet.cidr_block
    }
  }
}

output "interface_endpoint_ids" {
  description = "Interface endpoint identifiers keyed by service name"
  value       = var.interface_endpoint_ids
}

output "endpoint_security_group_id" {
  description = "Security group attached to interface VPC endpoints"
  value       = var.endpoint_security_group_id
}

output "s3_gateway_endpoint_id" {
  description = "Identifier for the S3 gateway endpoint in the shared VPC"
  value       = var.s3_gateway_endpoint_id
}

# Module declarations for shared security groups, RDS, ECS, EC2, etc. will be added per lab.
