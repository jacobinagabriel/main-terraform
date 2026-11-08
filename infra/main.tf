terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
  }

  required_version = ">= 1.10"
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}
