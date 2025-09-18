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

variable "vpc_id" {
  description = "Pre-provisioned VPC ID reused by the environment"
  type        = string
  default     = "vpc-075f21399ed8cdd47"
}

variable "public_subnet_ids" {
  description = "Pre-provisioned public subnet IDs"
  type        = list(string)
  default = [
    "subnet-0dd3f7f05ca1cb8d8",
    "subnet-0b7e614d07d9f6030",
  ]
}

variable "private_subnet_ids" {
  description = "Pre-provisioned private subnet IDs"
  type        = list(string)
  default = [
    "subnet-03d29cbce89aeaf14",
    "subnet-081e4da6ba7b7046e",
  ]
}
