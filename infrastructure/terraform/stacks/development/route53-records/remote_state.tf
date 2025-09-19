data "terraform_remote_state" "ecs_alb" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/compute-ecs-alb.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}
