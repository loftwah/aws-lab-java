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

# Module declarations for shared security groups, RDS, ECS, EC2, etc. will be added per lab.
