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

variable "connection_arn" {
  description = "AWS CodeConnections (CodeStar Connections) ARN for GitHub"
  type        = string
  default     = "arn:aws:codeconnections:ap-southeast-2:139294524816:connection/9cb5e242-3d9c-4b3c-8fec-fd3fdea9e37e"
}

variable "repo_full_name" {
  description = "GitHub owner/repo for source"
  type        = string
  default     = "loftwah/aws-lab-java"
}

variable "branch" {
  description = "Git branch to build from"
  type        = string
  default     = "main"
}

variable "manual_approval" {
  description = "Insert a manual approval between build and deploy"
  type        = bool
  default     = false
}

variable "ec2_instance_id" {
  description = "EC2 instance ID for EC2 deploy stage"
  type        = string
  default     = "i-081db86b9591e5f47"
}
