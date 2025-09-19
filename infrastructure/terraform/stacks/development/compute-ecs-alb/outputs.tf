output "alb_arn" {
  description = "ARN of the ECS application load balancer"
  value       = aws_lb.ecs.arn
}

output "alb_dns_name" {
  description = "DNS name of the ECS application load balancer"
  value       = aws_lb.ecs.dns_name
}

output "alb_listener_arn" {
  description = "ARN of the HTTP listener for the ECS application load balancer"
  value       = aws_lb_listener.http.arn
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID for the ECS application load balancer"
  value       = aws_lb.ecs.zone_id
}
