data "aws_caller_identity" "current" {}

locals {
  account_id                = data.aws_caller_identity.current.account_id
  secrets_prefix            = "aws-lab-java/${var.environment}"
  parameter_prefix          = "/aws-lab-java/${var.environment}/"
  widget_metadata_bucket    = data.terraform_remote_state.storage.outputs.widget_metadata_bucket_arn
  widget_metadata_bucket_id = data.terraform_remote_state.storage.outputs.widget_metadata_bucket_name
}

data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "aws-lab-java-${var.environment}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json

  tags = merge(local.base_tags, {
    Role = "ecs-task-execution"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ecs_task" {
  statement {
    sid    = "WidgetMetadataS3"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      local.widget_metadata_bucket,
      "${local.widget_metadata_bucket}/*"
    ]
  }

  statement {
    sid    = "ReadParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter${local.parameter_prefix}*"
    ]
  }

  statement {
    sid    = "ReadSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secrets_prefix}*"
    ]
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "aws-lab-java-${var.environment}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = merge(local.base_tags, {
    Role = "ecs-task"
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name   = "ecs-task-app"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task.json
}

data "aws_iam_policy_document" "ec2_instance_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ec2_instance" {
  statement {
    sid    = "WidgetMetadataS3"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      local.widget_metadata_bucket,
      "${local.widget_metadata_bucket}/*"
    ]
  }

  statement {
    sid    = "ReadParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter${local.parameter_prefix}*"
    ]
  }

  statement {
    sid    = "ReadSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secrets_prefix}*"
    ]
  }
}

resource "aws_iam_role" "ec2_service" {
  name               = "aws-lab-java-${var.environment}-ec2-service"
  assume_role_policy = data.aws_iam_policy_document.ec2_instance_assume.json

  tags = merge(local.base_tags, {
    Role = "ec2-service"
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_service.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_service" {
  name   = "ec2-service-app"
  role   = aws_iam_role.ec2_service.id
  policy = data.aws_iam_policy_document.ec2_instance.json
}

resource "aws_iam_instance_profile" "ec2_service" {
  name = "aws-lab-java-${var.environment}-ec2-service"
  role = aws_iam_role.ec2_service.name
}

output "ecs_task_execution_role_arn" {
  description = "IAM role ARN used by ECS task execution"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "IAM role ARN assigned to the ECS task definition"
  value       = aws_iam_role.ecs_task.arn
}

output "ec2_instance_profile_name" {
  description = "Instance profile name for EC2 workloads"
  value       = aws_iam_instance_profile.ec2_service.name
}

output "ec2_instance_role_arn" {
  description = "IAM role ARN assumed by EC2 workloads"
  value       = aws_iam_role.ec2_service.arn
}
