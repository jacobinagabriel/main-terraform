terraform {
  backend "s3" {
    bucket  = "gabriel-jacobina-terraform-state"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    profile = "849864070970_SystemAdministrator"
  }
}
