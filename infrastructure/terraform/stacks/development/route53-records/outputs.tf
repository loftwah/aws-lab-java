output "ecs_service_fqdn" {
  description = "Public DNS name for the ECS demo service"
  value       = local.ecs_record_fqdn
}
