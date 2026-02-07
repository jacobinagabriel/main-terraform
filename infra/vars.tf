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
  description = "AWS CLI profile"
  type        = string
  default     = "user1"
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

variable "db_password" {
  description = "Password for the PostgreSQL database"
  type        = string
  sensitive   = true
}