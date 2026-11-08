terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
  }

  # Separate state from env/prod. CI never applies this stack; the deploy role is
  # even denied writes to this key.
  backend "s3" {
    bucket       = "gabriel-jacobina-terraform-state"
    key          = "bootstrap/github-oidc.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project   = "main-terraform"
      stack     = "bootstrap/github-oidc"
      terraform = "true"
    }
  }
}

data "aws_caller_identity" "current" {}
