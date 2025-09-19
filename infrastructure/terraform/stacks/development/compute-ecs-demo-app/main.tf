data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix            = "aws-lab-java-${var.environment}"
  service_name           = "${local.name_prefix}-ecs-service"
  task_family            = "${local.name_prefix}-demo"
  container_name         = "aws-lab-java-demo"
  container_port         = 8080
  log_group_name         = "/aws/ecs/${local.service_name}"
  public_subnet_ids      = keys(data.terraform_remote_state.core_networking.outputs.public_subnets)
  private_subnet_ids     = keys(data.terraform_remote_state.core_networking.outputs.private_subnets)
  security_groups        = data.terraform_remote_state.core_networking.outputs.security_group_ids
  ecr_repository_url     = data.terraform_remote_state.container_registry.outputs.ecr_repository_url
  widget_metadata_bucket = data.terraform_remote_state.storage.outputs.widget_metadata_bucket_name
  datasource_parameters  = data.terraform_remote_state.database.outputs.datasource_parameter_names
  auth_token_parameter   = data.terraform_remote_state.security.outputs.app_auth_token_parameter_name
  datasource_parameter_arns = {
    for key, name in local.datasource_parameters :
    key => "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${name}"
  }
  auth_token_parameter_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.auth_token_parameter}"
  container_environment = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "aws"
    },
    {
      name  = "DEPLOYMENT_TARGET"
      value = "ecs"
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
    },
    {
      name  = "AWS_S3_METADATA_BUCKET"
      value = local.widget_metadata_bucket
    },
    {
      name  = "AWS_S3_METADATA_PREFIX"
      value = "widget-metadata/"
    }
  ]
  container_secrets = [
    {
      name      = "SPRING_DATASOURCE_URL"
      valueFrom = local.datasource_parameter_arns.url
    },
    {
      name      = "SPRING_DATASOURCE_USERNAME"
      valueFrom = local.datasource_parameter_arns.username
    },
    {
      name      = "SPRING_DATASOURCE_PASSWORD"
      valueFrom = local.datasource_parameter_arns.password
    },
    {
      name      = "DEMO_AUTH_TOKEN"
      valueFrom = local.auth_token_parameter_arn
    }
  ]
}

resource "aws_cloudwatch_log_group" "service" {
  name              = local.log_group_name
  retention_in_days = 30
}

resource "aws_lb_target_group" "service" {
  name        = "${local.name_prefix}-demo"
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.terraform_remote_state.core_networking.outputs.vpc_id

  health_check {
    path                = "/actuator/health"
    matcher             = "200-299"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb_listener_rule" "service" {
  listener_arn = data.terraform_remote_state.ecs_alb.outputs.alb_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = local.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.terraform_remote_state.security.outputs.ecs_task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.security.outputs.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "${local.ecr_repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = local.container_port
          hostPort      = local.container_port
          protocol      = "tcp"
        }
      ]
      environment = local.container_environment
      secrets     = local.container_secrets
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${local.container_port}/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name                               = local.service_name
  cluster                            = data.terraform_remote_state.ecs_cluster.outputs.cluster_id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  enable_execute_command             = true
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  network_configuration {
    assign_public_ip = false
    security_groups  = [local.security_groups.ecs]
    subnets          = local.private_subnet_ids
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  depends_on = [
    aws_lb_listener_rule.service
  ]
}
