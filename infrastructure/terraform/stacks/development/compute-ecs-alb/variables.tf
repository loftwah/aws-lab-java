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
