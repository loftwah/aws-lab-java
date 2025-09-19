output "ecr_repository_name" {
  description = "Name of the demo application ECR repository"
  value       = module.app_ecr.repository_name
}

output "ecr_repository_arn" {
  description = "ARN of the demo application ECR repository"
  value       = module.app_ecr.repository_arn
}

output "ecr_repository_url" {
  description = "URI of the demo application ECR repository"
  value       = module.app_ecr.repository_url
}
