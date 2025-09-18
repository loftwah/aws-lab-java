output "bucket_id" {
  description = "ID of the Terraform state bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.this.arn
}
