# main-terraform

The base layer of my AWS account (`us-east-1`): the things every project shares and that stay deployed. App repos (for example [source-app](https://github.com/jacobinagabriel/source-app)) build on top of it and never change it.

## Layout

| Path | What |
|---|---|
| `env/prod/` | Root module for the `prod` environment: backend, versions, module call |
| `infra/` | The resources, as one module |

## What app repos can use

The shared network is published to SSM Parameter Store, so app repos read it with `data "aws_ssm_parameter"` and never depend on this repo's state:

| Parameter | Type |
|---|---|
| `/main-terraform/prod/network/vpc_id` | String |
| `/main-terraform/prod/network/vpc_cidr` | String |
| `/main-terraform/prod/network/azs` | StringList |
| `/main-terraform/prod/network/public_subnet_ids` | StringList |
| `/main-terraform/prod/network/private_subnet_ids` | StringList |

The VPC costs nothing while idle. App tasks run in public subnets with a public IP and no inbound rules; databases go in private subnets. A NAT gateway (`enable_nat_gateway`) and interface endpoints (`interface_endpoints`) are opt-in because they cost money every hour.

State lives in S3: bucket `gabriel-jacobina-terraform-state`, key `prod/terraform.tfstate`.

## Applying

Changes land through pull requests. CI (`terraform`) checks formatting, validates, lints (tflint) and scans (checkov) every PR. Checkov includes a custom check in `.checkov/checks/`: every `aws_iam_role` must set a `permissions_boundary`. To skip a check, add `#checkov:skip=<ID>:<reason>` inside the resource; the reason is required reading in review.

To apply from your machine (Terraform ≥ 1.10):

```bash
export AWS_PROFILE=<your SSO profile>   # the provider and backend no longer hardcode one
aws sso login
cd env/prod
terraform init -reconfigure            # needed once after the backend change (use_lockfile)
terraform plan -out tfplan
terraform apply tfplan
```
