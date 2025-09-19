locals {
  base_tags = {
    Owner       = "Dean Lofts"
    Environment = var.environment
    Project     = "aws-lab-java"
    App         = "aws-lab-java"
    ManagedBy   = "Terraform"
  }

  repository_name = "aws-lab-java-demo"
}
