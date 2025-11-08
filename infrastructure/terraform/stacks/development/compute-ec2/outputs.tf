output "ec2_instance_id" {
  description = "EC2 instance ID for the EC2-based app"
  value       = aws_instance.app.id
}

output "ec2_instance_private_ip" {
  description = "Private IP address of the EC2 app instance"
  value       = aws_instance.app.private_ip
}

output "ec2_target_group_arn" {
  description = "Target group ARN for the EC2 app"
  value       = aws_lb_target_group.ec2_service.arn
}

