data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "state_bucket" {
  source = "../modules/state_bucket"

  bucket_name           = var.bucket_name
  force_destroy         = var.force_destroy
  object_lifecycle_days = var.object_lifecycle_days
}

output "bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = module.state_bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = module.state_bucket.bucket_arn
}

output "account_id" {
  description = "AWS account ID where the state bucket exists"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS region used for the state bucket"
  value       = data.aws_region.current.name
}
