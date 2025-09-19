output "artifact_bucket_name" {
  description = "S3 bucket storing CodePipeline artifacts"
  value       = aws_s3_bucket.artifacts.id
}

output "codebuild_project_name" {
  description = "CodeBuild project that builds the demo container image"
  value       = aws_codebuild_project.image_builder.name
}

output "codepipeline_name" {
  description = "CodePipeline orchestrating source and build stages"
  value       = aws_codepipeline.image_pipeline.name
}

output "ecr_repository_url" {
  description = "URI of the demo application's ECR repository"
  value       = local.ecr_repository_url
}
