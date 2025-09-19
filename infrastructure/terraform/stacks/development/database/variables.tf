variable "aws_region" {
  description = "AWS region for the environment"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "devops-sandbox"
}

variable "environment" {
  description = "Environment name used for tagging and resource naming"
  type        = string
  default     = "development"
}

variable "additional_tags" {
  description = "Optional additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "db_instance_class" {
  description = "RDS instance class for the PostgreSQL database"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial storage (GiB) allocated to the database instance"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage (GiB) that autoscaling can allocate to the database"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Initial database name to create"
  type        = string
  default     = "demo"
}

variable "db_master_username" {
  description = "Master username for the PostgreSQL instance"
  type        = string
  default     = "demoadmin"
}

variable "db_port" {
  description = "Port the PostgreSQL instance listens on"
  type        = number
  default     = 5432
}

variable "db_engine_version" {
  description = "Exact engine version to use for the PostgreSQL instance"
  type        = string
  default     = "16.4"
}

variable "db_parameter_group_family" {
  description = "Parameter group family matching the selected PostgreSQL engine version"
  type        = string
  default     = "postgres16"
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ deployment for the database"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection on the database instance"
  type        = bool
  default     = false
}

variable "db_performance_insights_retention_period" {
  description = "Retention period (days) for Performance Insights data"
  type        = number
  default     = 7
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip creating a final snapshot when the database is destroyed"
  type        = bool
  default     = true
}
