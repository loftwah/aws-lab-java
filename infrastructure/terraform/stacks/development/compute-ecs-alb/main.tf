resource "aws_lb" "ecs" {
  name               = "${local.name_prefix}-ecs"
  load_balancer_type = "application"
  security_groups    = [data.terraform_remote_state.core_networking.outputs.security_group_ids.alb]
  subnets            = keys(data.terraform_remote_state.core_networking.outputs.public_subnets)
  idle_timeout       = 60
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not configured"
      status_code  = "404"
    }
  }
}
