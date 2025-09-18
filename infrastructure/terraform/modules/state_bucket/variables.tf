variable "bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even if it contains objects"
  type        = bool
  default     = false
}

variable "block_public_access" {
  description = "Toggle for applying AWS-recommended public access blocks"
  type        = bool
  default     = true
}

variable "object_lifecycle_days" {
  description = "Number of days before non-current object versions transition to Glacier. Disabled when null."
  type        = number
  default     = null
}
