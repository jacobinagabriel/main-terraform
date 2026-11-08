# bootstrap/github-oidc

Lets GitHub Actions in `main-terraform` and `source-app` use AWS without stored keys, and limits what those pipelines can do. **Apply it from your machine only.** CI validates and scans it but never applies it, and the deploy role is denied writes to its state.

| Resource | Purpose |
|---|---|
| OIDC provider `token.actions.githubusercontent.com` | GitHub's identity tokens can be exchanged for AWS credentials |
| Role `github-actions-terraform-plan` | Assumable from **pull requests** of the listed repos. `ReadOnlyAccess` + read state + write `*.tflock` |
| Role `github-actions-terraform-deploy` | Assumable only from the **`prod` GitHub Environment** (needs your approval). `PowerUserAccess` + state + bounded IAM (below) |
| Policy `app-role-boundary` | Permissions boundary every app-created role must carry: a ceiling of app services, with all IAM denied |
| SSM `/main-terraform/prod/iam/*` | `app_role_boundary_arn`, `github_plan_role_arn`, `github_deploy_role_arn` |

## What the deploy role can and can't do in IAM

- Create roles, or add policies to them, **only** for names `source-app-*` / `main-terraform-*`, and **only** when the role carries `app-role-boundary` (`iam:PermissionsBoundary` condition).
- Explicitly denied:
  - removing a boundary, or setting any other boundary
  - changing the `app-role-boundary` policy
  - touching `github-actions-*` roles or the OIDC provider
  - overwriting `/main-terraform/prod/iam/*`
  - writing `bootstrap/*` state

So even a malicious PR that gets applied can't give the pipeline more power than it has today. Checkov (`CKV2_CUSTOM_1`) flags a missing boundary in review; AWS enforces it at apply time.

## Apply

```bash
export AWS_PROFILE=<your SSO profile>   # an admin profile: this stack creates IAM
aws sso login
cd bootstrap/github-oidc
terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

If you already created the provider or roles in the console, copy `imports.tf.example` to `imports.tf` first (see the comments in it), so they're imported instead of recreated.

Then set the repo variables in both repos (Settings → Secrets and variables → Actions → Variables): `AWS_REGION=us-east-1`, `AWS_PLAN_ROLE_ARN`, `AWS_DEPLOY_ROLE_ARN` (from `terraform output`).
