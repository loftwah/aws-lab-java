locals {
  ecr_repository_name = "aws-lab-java-demo"
}

module "app_ecr" {
  source = "../../../modules/ecr-repository"

  name                 = local.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"
  lifecycle_keep_count = 15
}

output "ecr_repository_name" {
  description = "Name of the demo application ECR repository"
  value       = module.app_ecr.repository_name
}

output "ecr_repository_url" {
  description = "URI for pushing application images"
  value       = module.app_ecr.repository_url
}
