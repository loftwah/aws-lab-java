locals {
  base_tags = {
    Owner       = "Dean Lofts"
    Environment = var.environment
    Project     = "aws-lab-java"
    App         = "aws-lab-java"
    ManagedBy   = "Terraform"
  }

  ecs_record_fqdn = "${var.ecs_service_subdomain}.${var.zone_name}"
}
