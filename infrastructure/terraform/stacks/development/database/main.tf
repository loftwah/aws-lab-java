locals {
  private_subnet_ids         = keys(data.terraform_remote_state.core_networking.outputs.private_subnets)
  database_security_group_id = data.terraform_remote_state.core_networking.outputs.security_group_ids.database
  database_tags              = merge(local.base_tags, var.additional_tags, { Component = "database" })
  datasource_parameters = {
    url      = "${local.parameter_prefix}SPRING_DATASOURCE_URL"
    username = "${local.parameter_prefix}SPRING_DATASOURCE_USERNAME"
    password = "${local.parameter_prefix}SPRING_DATASOURCE_PASSWORD"
  }
}

resource "random_password" "db_master" {
  length           = 20
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*+-=?@^_"
}

resource "aws_db_subnet_group" "postgres" {
  name        = "${local.name_prefix}-db-subnets"
  description = "Private subnets for the shared PostgreSQL instance"
  subnet_ids  = local.private_subnet_ids

  tags = local.database_tags
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${local.name_prefix}-postgres"
  family = var.db_parameter_group_family

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = local.database_tags
}

resource "aws_db_instance" "postgres" {
  identifier                            = "${local.name_prefix}-postgres"
  engine                                = "postgres"
  engine_version                        = var.db_engine_version
  instance_class                        = var.db_instance_class
  allocated_storage                     = var.db_allocated_storage
  max_allocated_storage                 = var.db_max_allocated_storage
  storage_type                          = "gp3"
  db_name                               = var.db_name
  username                              = var.db_master_username
  password                              = random_password.db_master.result
  port                                  = var.db_port
  db_subnet_group_name                  = aws_db_subnet_group.postgres.name
  vpc_security_group_ids                = [local.database_security_group_id]
  parameter_group_name                  = aws_db_parameter_group.postgres.name
  publicly_accessible                   = false
  storage_encrypted                     = true
  backup_retention_period               = var.db_backup_retention_period
  copy_tags_to_snapshot                 = true
  auto_minor_version_upgrade            = true
  multi_az                              = var.db_multi_az
  deletion_protection                   = var.db_deletion_protection
  skip_final_snapshot                   = var.db_skip_final_snapshot
  performance_insights_enabled          = true
  performance_insights_retention_period = var.db_performance_insights_retention_period
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  tags = local.database_tags
}

resource "aws_secretsmanager_secret" "database_credentials" {
  name        = "${local.secrets_prefix}/database/postgresql"
  description = "JDBC credentials for the aws-lab-java PostgreSQL instance"

  tags = local.database_tags
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  secret_id = aws_secretsmanager_secret.database_credentials.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = var.db_port
    dbname   = var.db_name
    username = var.db_master_username
    password = random_password.db_master.result
    jdbcUrl  = "jdbc:postgresql://${aws_db_instance.postgres.address}:${var.db_port}/${var.db_name}"
  })
}

resource "aws_ssm_parameter" "datasource_username" {
  name      = local.datasource_parameters.username
  type      = "String"
  value     = var.db_master_username
  overwrite = true

  tags = local.database_tags
}

resource "aws_ssm_parameter" "datasource_password" {
  name      = local.datasource_parameters.password
  type      = "SecureString"
  value     = random_password.db_master.result
  overwrite = true

  tags = local.database_tags
}

resource "aws_ssm_parameter" "datasource_url" {
  name      = local.datasource_parameters.url
  type      = "String"
  value     = "jdbc:postgresql://${aws_db_instance.postgres.address}:${var.db_port}/${var.db_name}"
  overwrite = true

  tags = local.database_tags
}
