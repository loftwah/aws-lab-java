data "terraform_remote_state" "core_networking" {
  backend = "s3"

  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/core-networking.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}
