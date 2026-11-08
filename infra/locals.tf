locals {
  common_tags = merge(
    var.common_tags,
    {
      env       = var.env
      project   = var.project_name
      terraform = "true"
    }
  )
}