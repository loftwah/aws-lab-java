data "terraform_remote_state" "core_networking" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/core-networking.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "ecs_cluster" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/compute-ecs-cluster.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "ecs_alb" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/compute-ecs-alb.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/security.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "storage" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/storage.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "container_registry" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/container-registry.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/database.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}
