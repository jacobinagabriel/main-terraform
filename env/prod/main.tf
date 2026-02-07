module "prod" {
  source = "../../infra"

  env          = "prod"
  aws_region   = "us-east-1"
  aws_profile  = "849864070970_SystemAdministrator"
  project_name = "main-terraform"
  db_password  = var.db_password

}