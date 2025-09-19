locals {
  base_tags = {
    Owner       = "Dean Lofts"
    Environment = var.environment
    Project     = "aws-lab-java"
    App         = "aws-lab-java"
    ManagedBy   = "Terraform"
  }

  name_prefix      = "aws-lab-java-${var.environment}"
  secrets_prefix   = "aws-lab-java/${var.environment}"
  parameter_prefix = "/app/aws-lab-java/${var.environment}/"
}
