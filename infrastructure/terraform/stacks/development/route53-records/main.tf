data "aws_route53_zone" "primary" {
  name         = var.zone_name
  private_zone = false
}

data "aws_lb" "ecs" {
  arn = data.terraform_remote_state.ecs_alb.outputs.alb_arn
}

resource "aws_route53_record" "ecs_service" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.ecs_service_subdomain
  type    = "A"

  alias {
    name                   = data.terraform_remote_state.ecs_alb.outputs.alb_dns_name
    zone_id                = data.aws_lb.ecs.zone_id
    evaluate_target_health = true
  }
}
