output "vpc_id" {
  description = "Shared VPC id"
  value       = module.prod.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet ids, one per AZ"
  value       = module.prod.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet ids, one per AZ"
  value       = module.prod.private_subnet_ids
}

output "ssm_prefix" {
  description = "Prefix of the SSM parameters app repos read"
  value       = module.prod.ssm_prefix
}
