# GitHub Actions → AWS with OIDC

GitHub Actions in `main-terraform` and `source-app` get short-lived AWS credentials through OpenID Connect. There are no AWS access keys anywhere: a workflow presents a GitHub-signed token, and AWS only accepts it for the roles and repo/event combinations listed in the trust policies.

## 1. Apply the bootstrap stack from your machine (recommended)

Everything lives in [`bootstrap/github-oidc`](../bootstrap/github-oidc/README.md): the OIDC provider, the plan and deploy roles, and the `app-role-boundary` policy. You need an admin profile, because the stack creates IAM resources.

```bash
export AWS_PROFILE=<your admin SSO profile>
aws sso login
cd bootstrap/github-oidc
terraform init
terraform plan -out tfplan    # expect: 1 provider, 2 roles, 1 boundary policy, attachments, 3 SSM parameters
terraform apply tfplan
terraform output
```

CI never applies this stack, and the deploy role it creates is denied writes to this stack's state.

## 2. GitHub settings (both repositories)

1. **Settings → Environments → `prod`**: add yourself under *Required reviewers*, and under *Deployment branches* allow only `main`. (Already created if you followed the PRs; check that it's there.)
2. **Settings → Secrets and variables → Actions → Variables**:
   - `AWS_REGION` = `us-east-1`
   - `AWS_PLAN_ROLE_ARN` = `terraform output -raw plan_role_arn`
   - `AWS_DEPLOY_ROLE_ARN` = `terraform output -raw deploy_role_arn`

Once `AWS_PLAN_ROLE_ARN` is set, every pull request gets a `plan` job that comments the plan. **Actions → Apply → Run workflow** applies `main` after you approve the `prod` deployment.

## How the roles are limited

| Role | Who can assume it | Can do |
|---|---|---|
| `github-actions-terraform-plan` | `pull_request` events of the two repos | read everything (`ReadOnlyAccess`), read state, write lock files |
| `github-actions-terraform-deploy` | jobs in the `prod` environment of the two repos (your approval, `main` only) | `PowerUserAccess` + state + IAM only for `source-app-*`/`main-terraform-*` roles that carry `app-role-boundary` |

The deploy role is explicitly denied:
- removing or swapping the boundary
- editing the boundary policy
- touching the `github-actions-*` roles or the OIDC provider
- overwriting the published ARNs in SSM
- writing the bootstrap state

## Optional: create the pieces in the console instead

Only if you'd rather click than apply step 1. The policies are long, so the roles are much easier to get right with Terraform. A middle ground: create just the identity provider in the console, then apply step 1 with an import.

1. **IAM → Identity providers → Add provider**
   - Provider type: *OpenID Connect*
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
2. **IAM → Roles → Create role → Web identity**, provider `token.actions.githubusercontent.com`, audience `sts.amazonaws.com`, GitHub organization `jacobinagabriel`. Then edit the trust policy so `token.actions.githubusercontent.com:sub` is exactly:
   - plan role `github-actions-terraform-plan`: `repo:jacobinagabriel/main-terraform:pull_request`, `repo:jacobinagabriel/source-app:pull_request`
   - deploy role `github-actions-terraform-deploy`: `repo:jacobinagabriel/main-terraform:environment:prod`, `repo:jacobinagabriel/source-app:environment:prod`
3. Attach `ReadOnlyAccess` (plan) and `PowerUserAccess` (deploy). Copy the inline policies from `terraform plan` output in `bootstrap/github-oidc` (`terraform-state`, `bounded-iam`), and create the `app-role-boundary` policy the same way.
4. Bring them under Terraform: copy `bootstrap/github-oidc/imports.tf.example` to `imports.tf`, fill in the account id, run `terraform plan` (it should show *import*, not *create*), apply, then delete `imports.tf`.
