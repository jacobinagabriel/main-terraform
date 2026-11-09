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

variable "github_owner_id" {
  description = "Numeric ID of the GitHub owner (gh api users/<owner> --jq .id). It's never reassigned, unlike the name"
  type        = number
  default     = 146280129
}

variable "repositories" {
  description = "Repositories whose workflows may assume the roles: name => numeric ID (gh api repos/<owner>/<repo> --jq .id)"
  type        = map(number)
  default = {
    "main-terraform" = 1110283550
    "source-app"     = 1450656531
  }
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
