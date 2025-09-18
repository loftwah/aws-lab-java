variable "aws_region" {
  description = "AWS region where the state bucket will reside"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile used for state bootstrap"
  type        = string
  default     = "devops-sandbox"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
  default     = "aws-lab-java-terraform-state"
}

variable "force_destroy" {
  description = "Allow Terraform to delete the state bucket even if it contains objects"
  type        = bool
  default     = false
}

variable "object_lifecycle_days" {
  description = "Optional days before non-current state object versions transition to Glacier"
  type        = number
  default     = 30
}
