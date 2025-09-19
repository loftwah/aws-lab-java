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

variable "zone_name" {
  description = "Public hosted zone name where application records are created"
  type        = string
  default     = "aws.deanlofts.xyz"
}

variable "ecs_service_subdomain" {
  description = "Subdomain used for the ECS demo service"
  type        = string
  default     = "java-demo-ecs"
}

variable "ec2_service_subdomain" {
  description = "Subdomain used for the EC2 demo service"
  type        = string
  default     = "java-demo-ec2"
}
