module "app_ecr" {
  source = "../../../modules/ecr-repository"

  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"
  lifecycle_keep_count = 15
}
