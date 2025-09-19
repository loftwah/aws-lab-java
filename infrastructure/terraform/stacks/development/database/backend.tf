terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket       = "aws-lab-java-terraform-state"
    key          = "development/database.tfstate"
    region       = "ap-southeast-2"
    profile      = "devops-sandbox"
    encrypt      = true
    use_lockfile = true
  }
}
