provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = merge(local.base_tags, var.additional_tags)
  }
}
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = merge(local.base_tags, var.additional_tags)
  }
}
