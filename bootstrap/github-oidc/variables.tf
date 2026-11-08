variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repositories"
  type        = string
  default     = "jacobinagabriel"
}

variable "repositories" {
  description = "Repositories whose workflows may assume the roles"
  type        = list(string)
  default     = ["main-terraform", "source-app"]
}

variable "deploy_environment" {
  description = "GitHub Environment that may assume the deploy role (it requires your approval)"
  type        = string
  default     = "prod"
}

variable "state_bucket" {
  description = "Bucket holding every Terraform state"
  type        = string
  default     = "gabriel-jacobina-terraform-state"
}

variable "app_role_prefixes" {
  description = "Name prefixes of the IAM roles and policies the deploy role may manage"
  type        = list(string)
  default     = ["source-app-", "main-terraform-"]
}

variable "ssm_prefix" {
  description = "SSM path where this stack publishes its ARNs"
  type        = string
  default     = "/main-terraform/prod/iam"
}
