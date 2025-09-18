provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Owner       = "Dean Lofts"
      Environment = "bootstrap"
      Project     = "aws-lab-java"
      App         = "aws-lab-java"
      ManagedBy   = "Terraform"
    }
  }
}
