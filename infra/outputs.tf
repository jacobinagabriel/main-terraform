output "vpc_id" {
  description = "Shared VPC id"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet ids, one per AZ"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet ids, one per AZ"
  value       = module.vpc.private_subnets
}

output "ssm_prefix" {
  description = "Prefix of the SSM parameters app repos read"
  value       = local.ssm_prefix
}

output "app_repository_urls" {
  description = "ECR repository URL per app"
  value       = { for app, repo in aws_ecr_repository.app : app => repo.repository_url }
}
