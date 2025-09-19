output "database_identifier" {
  description = "RDS instance identifier for the shared PostgreSQL database"
  value       = aws_db_instance.postgres.id
}

output "database_endpoint" {
  description = "DNS endpoint for the PostgreSQL instance"
  value       = aws_db_instance.postgres.address
}

output "database_port" {
  description = "Port number clients should use when connecting to PostgreSQL"
  value       = var.db_port
}

output "database_name" {
  description = "Primary database created on the PostgreSQL instance"
  value       = var.db_name
}

output "database_secret_arn" {
  description = "Secrets Manager ARN containing PostgreSQL credentials"
  value       = aws_secretsmanager_secret.database_credentials.arn
}

output "database_secret_name" {
  description = "Secrets Manager name for the PostgreSQL credentials"
  value       = aws_secretsmanager_secret.database_credentials.name
}

output "datasource_parameter_names" {
  description = "Parameter Store keys that supply Spring datasource configuration"
  value       = local.datasource_parameters
}
