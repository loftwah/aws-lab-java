output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "target_group_arn" {
  description = "ARN of the ECS service target group"
  value       = aws_lb_target_group.service.arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.app.arn
}

output "listener_rule_arn" {
  description = "ARN of the listener rule forwarding traffic to the service"
  value       = aws_lb_listener_rule.service.arn
}

output "load_balancer_dns" {
  description = "DNS name of the shared ECS application load balancer"
  value       = data.terraform_remote_state.ecs_alb.outputs.alb_dns_name
}
