resource "aws_ecr_repository" "repo" {
  #checkov:skip=CKV_AWS_51:Legacy shared repo that relies on mutable tags; app repos get immutable ones.
  #checkov:skip=CKV_AWS_136:AES-256 encryption at rest (the ECR default) is enough; no KMS key to manage.
  name = "${var.account_name}-${var.env}-ecr-repository"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}