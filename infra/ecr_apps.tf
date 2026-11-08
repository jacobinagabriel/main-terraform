# One image repository per app repo. Images are tagged with the git SHA, so tags are
# immutable: a tag always means the same image.
resource "aws_ecr_repository" "app" {
  for_each = toset(var.app_repositories)
  #checkov:skip=CKV_AWS_136:AES-256 encryption at rest (the ECR default) is enough; no KMS key to manage.

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, { app = each.value })
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each = aws_ecr_repository.app

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last ${var.app_image_retention} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.app_image_retention
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ssm_parameter" "app_ecr" {
  for_each = merge([
    for app, repo in aws_ecr_repository.app : {
      "${app}/repository_url" = repo.repository_url
      "${app}/repository_arn" = repo.arn
    }
  ]...)
  #checkov:skip=CKV2_AWS_34:Repository URLs and ARNs are not secrets.

  name  = "${local.ssm_prefix}/ecr/${each.key}"
  type  = "String"
  value = each.value

  tags = local.common_tags
}
