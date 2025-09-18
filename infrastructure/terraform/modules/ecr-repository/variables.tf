variable "name" {
  description = "ECR repository name"
  type        = string
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten"
  type        = string
  default     = "IMMUTABLE"
  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE"
  }
}

variable "scan_on_push" {
  description = "Enable ECR image scanning on push"
  type        = bool
  default     = true
}

variable "lifecycle_keep_count" {
  description = "Number of most recent images to retain"
  type        = number
  default     = 10
  validation {
    condition     = var.lifecycle_keep_count >= 0
    error_message = "lifecycle_keep_count must be non-negative"
  }
}

variable "encryption_type" {
  description = "ECR encryption type"
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be AES256 or KMS"
  }
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN when using KMS encryption"
  type        = string
  default     = ""
  validation {
    condition     = !(var.encryption_type == "KMS" && var.kms_key_arn == "")
    error_message = "kms_key_arn must be supplied when encryption_type is KMS"
  }
}
