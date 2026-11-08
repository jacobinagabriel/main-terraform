resource "aws_ecr_repository" "repo" {
  name = "${var.account_name}-${var.env}-ecr-repository"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}