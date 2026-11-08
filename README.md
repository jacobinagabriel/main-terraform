# main-terraform

The base layer of my AWS account (`us-east-1`): the things every project shares and that stay deployed. App repos (for example [source-app](https://github.com/jacobinagabriel/source-app)) build on top of it and never change it.

## Layout

| Path | What |
|---|---|
| `env/prod/` | Root module for the `prod` environment: backend, versions, module call |
| `infra/` | The resources, as one module |

State lives in S3: bucket `gabriel-jacobina-terraform-state`, key `prod/terraform.tfstate`.

## Applying

Changes land through pull requests. CI (`terraform`) checks formatting, validates and lints every PR.

To apply from your machine (Terraform ≥ 1.10):

```bash
export AWS_PROFILE=<your SSO profile>   # the provider and backend no longer hardcode one
aws sso login
cd env/prod
terraform init -reconfigure            # needed once after the backend change (use_lockfile)
terraform plan -out tfplan
terraform apply tfplan
```
