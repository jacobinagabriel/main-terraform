variable "env" {
  description = "The name of the environment (e.g., prod, dev)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_name" {
  description = "AWS account name"
  type        = string
  default     = "gabriel-jacobina"
}

variable "aws_profile" {
  description = "AWS CLI profile. Leave null to use AWS_PROFILE or the GitHub OIDC role."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "main-terraform"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR of the shared VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability zones, pinned so the subnet layout never shifts when AWS adds a zone"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Create a single NAT gateway for private subnets (~$33/month plus data)"
  type        = bool
  default     = false
}

variable "interface_endpoints" {
  description = "Interface endpoint services to create, e.g. [\"ecr.api\", \"ecr.dkr\", \"logs\"] (~$7.30/month each per AZ)"
  type        = list(string)
  default     = []
}

variable "app_repositories" {
  description = "App repos that get their own ECR repository (named after the app)"
  type        = list(string)
  default     = ["source-app"]
}

variable "app_image_retention" {
  description = "How many images each app ECR repository keeps"
  type        = number
  default     = 20
}
