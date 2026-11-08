module "prod" {
  source = "../../infra"

  env          = "prod"
  aws_region   = "us-east-1"
  project_name = "main-terraform"
}