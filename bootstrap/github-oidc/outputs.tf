output "oidc_provider_arn" {
  description = "GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "plan_role_arn" {
  description = "Set as repo variable AWS_PLAN_ROLE_ARN"
  value       = aws_iam_role.plan.arn
}

output "deploy_role_arn" {
  description = "Set as repo variable AWS_DEPLOY_ROLE_ARN"
  value       = aws_iam_role.deploy.arn
}

output "app_role_boundary_arn" {
  description = "Set as permissions_boundary on every aws_iam_role in app repos"
  value       = aws_iam_policy.app_role_boundary.arn
}
