data "aws_caller_identity" "current" {}

locals {
  artifact_bucket_name = lower(
    "aws-lab-java-${var.environment}-cicd-artifacts-${data.aws_caller_identity.current.account_id}"
  )
  pipeline_name       = "aws-lab-java-${var.environment}-image-pipeline"
  build_project_name  = "aws-lab-java-${var.environment}-image-build"
  ecr_repository_url  = data.terraform_remote_state.container_registry.outputs.ecr_repository_url
  ecr_repository_name = data.terraform_remote_state.container_registry.outputs.ecr_repository_name
  ecs_cluster_arn     = data.terraform_remote_state.ecs_cluster.outputs.cluster_arn
  ecs_service_name    = data.terraform_remote_state.ecs_demo.outputs.service_name
}

resource "aws_s3_bucket" "artifacts" {
  bucket = local.artifact_bucket_name

  tags = merge(local.base_tags, {
    Component = "cicd-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "aws-lab-java-${var.environment}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json

  tags = merge(local.base_tags, {
    Role = "codebuild-service"
  })
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid    = "AllowLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowArtifactBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }

  statement {
    sid       = "AllowEcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEcrPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [data.aws_ecr_repository.app.arn]
  }

  statement {
    sid       = "AllowStsCallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "aws-lab-java-${var.environment}-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json

  tags = merge(local.base_tags, {
    Role = "codepipeline-service"
  })
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid    = "AllowArtifactBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }

  statement {
    sid    = "AllowCodeBuild"
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = [aws_codebuild_project.image_builder.arn]
  }

  statement {
    sid       = "AllowCodeStar"
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [var.connection_arn]
  }

  statement {
    sid       = "AllowPassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.codebuild.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}

data "aws_ecr_repository" "app" {
  name = local.ecr_repository_name
}

resource "aws_codebuild_project" "image_builder" {
  name          = local.build_project_name
  description   = "Builds and pushes the demo application container image to ECR"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "IMAGE_REPO_URI"
      value = local.ecr_repository_url
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = local.ecr_repository_name
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${local.build_project_name}"
      stream_name = "build"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspecs/build-image.yml"
  }

  tags = merge(local.base_tags, {
    Component = "codebuild"
  })
}

resource "aws_codepipeline" "image_pipeline" {
  name     = local.pipeline_name
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        ConnectionArn        = var.connection_arn
        FullRepositoryId     = var.repo_full_name
        BranchName           = var.branch
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.image_builder.name
      }
    }
  }

  dynamic "stage" {
    for_each = var.manual_approval ? [1] : []
    content {
      name = "Approve"
      action {
        name            = "ManualApproval"
        category        = "Approval"
        owner           = "AWS"
        provider        = "Manual"
        version         = "1"
        input_artifacts = ["BuildOutput"]
      }
    }
  }

  stage {
    name = "Deploy_ECS"

    action {
      name            = "DeployECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildOutput"]

      configuration = {
        ClusterName = local.ecs_cluster_arn
        ServiceName = local.ecs_service_name
        FileName    = "imageDetail.json"
      }
    }
  }

  stage {
    name = "Deploy_EC2"

    action {
      name            = "DeployEC2"
      category        = "Invoke"
      owner           = "AWS"
      provider        = "Lambda"
      version         = "1"
      input_artifacts = ["BuildOutput"]

      configuration = {
        FunctionName = aws_lambda_function.ec2_deploy.name
        UserParameters = jsonencode({
          instanceId = var.ec2_instance_id
          region     = var.aws_region
        })
      }
    }
  }

  tags = merge(local.base_tags, {
    Component = "codepipeline"
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/.tmp/ec2_deploy.zip"

  source {
    content  = <<-PY
import boto3, json, os

def handler(event, context):
    params = json.loads(event.get('UserParameters', '{}')) if isinstance(event.get('UserParameters'), str) else event.get('UserParameters', {})
    instance_id = params.get('instanceId')
    region = params.get('region', os.environ.get('AWS_REGION'))
    ssm = boto3.client('ssm', region_name=region)
    account_id = boto3.client('sts').get_caller_identity()['Account']
    ecr = f"{account_id}.dkr.ecr.{region}.amazonaws.com/aws-lab-java-demo"
    cmds = [
        "set -e",
        f"/usr/local/bin/aws ecr get-login-password --region {region} | docker login --username AWS --password-stdin {ecr}",
        f"docker pull {ecr}:latest",
        f"DEMO_AUTH_TOKEN=$(/usr/local/bin/aws ssm get-parameter --with-decryption --region {region} --name /app/aws-lab-java/development/DEMO_AUTH_TOKEN --query Parameter.Value --output text)",
        f"SPRING_DATASOURCE_URL=$(/usr/local/bin/aws ssm get-parameter --region {region} --name /app/aws-lab-java/development/SPRING_DATASOURCE_URL --query Parameter.Value --output text)",
        f"SPRING_DATASOURCE_USERNAME=$(/usr/local/bin/aws ssm get-parameter --region {region} --name /app/aws-lab-java/development/SPRING_DATASOURCE_USERNAME --query Parameter.Value --output text)",
        f"SPRING_DATASOURCE_PASSWORD=$(/usr/local/bin/aws ssm get-parameter --with-decryption --region {region} --name /app/aws-lab-java/development/SPRING_DATASOURCE_PASSWORD --query Parameter.Value --output text)",
        "docker rm -f aws-lab-java-demo || true",
        "docker run -d --name aws-lab-java-demo --restart always -p 8080:8080 "
        "-e SPRING_PROFILES_ACTIVE=aws -e DEPLOYMENT_TARGET=ec2 "
        f"-e AWS_REGION={region} -e AWS_S3_METADATA_BUCKET=aws-lab-java-development-widget-metadata -e AWS_S3_METADATA_PREFIX=widget-metadata/ "
        "-e DEMO_AUTH_TOKEN=$DEMO_AUTH_TOKEN -e SPRING_DATASOURCE_URL=\"$SPRING_DATASOURCE_URL\" -e SPRING_DATASOURCE_USERNAME=\"$SPRING_DATASOURCE_USERNAME\" -e SPRING_DATASOURCE_PASSWORD=\"$SPRING_DATASOURCE_PASSWORD\" "
        f"{ecr}:latest"
    ]
    resp = ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName='AWS-RunShellScript',
        Parameters={'commands': cmds}
    )
    return {'commandId': resp['Command']['CommandId']}
PY
    filename = "index.py"
  }
}

resource "aws_iam_role" "lambda" {
  name = "aws-lab-java-${var.environment}-ec2-deploy-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
      { Effect = "Allow", Action = ["ssm:SendCommand"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["sts:GetCallerIdentity"], Resource = "*" }
    ]
  })
}

resource "aws_lambda_function" "ec2_deploy" {
  function_name = "aws-lab-java-${var.environment}-ec2-deploy"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.lambda_zip.output_path
}
