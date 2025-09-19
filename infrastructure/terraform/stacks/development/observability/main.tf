data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "alerts" {
  name = "aws-lab-java-${var.environment}-alerts"
  tags = merge(local.base_tags, { Component = "alerts" })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ALB 5xx alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "aws-lab-java-${var.environment}-alb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = data.terraform_remote_state.ecs_alb.outputs.alb_arn
  }

  alarm_description = "ALB 5xx spikes"
  alarm_actions     = [aws_sns_topic.alerts.arn]
  ok_actions        = [aws_sns_topic.alerts.arn]
}

# ECS service CPU alarm
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "aws-lab-java-${var.environment}-ecs-high-cpu"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ClusterName = data.terraform_remote_state.ecs_cluster.outputs.cluster_name
    ServiceName = data.terraform_remote_state.ecs_demo.outputs.service_name
  }

  alarm_description = "ECS service CPU >= 80% for 3m"
  alarm_actions     = [aws_sns_topic.alerts.arn]
  ok_actions        = [aws_sns_topic.alerts.arn]
}

# Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "aws-lab-java-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x    = 0, y = 0, width = 12, height = 6,
        properties = {
          title   = "ALB 5xx",
          metrics = [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", data.terraform_remote_state.ecs_alb.outputs.alb_arn]],
          period  = 60, stat = "Sum", view = "timeSeries", region = var.aws_region
        }
      },
      {
        type = "metric",
        x    = 12, y = 0, width = 12, height = 6,
        properties = {
          title   = "ECS CPU",
          metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", data.terraform_remote_state.ecs_cluster.outputs.cluster_name, "ServiceName", data.terraform_remote_state.ecs_demo.outputs.service_name]],
          period  = 60, stat = "Average", view = "timeSeries", region = var.aws_region
        }
      }
    ]
  })
}
# TODO: Add resources/modules for the observability stack.
