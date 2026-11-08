locals {
  account_id = data.aws_caller_identity.current.account_id

  oidc_host = "token.actions.githubusercontent.com"

  plan_subjects   = [for repo in var.repositories : "repo:${var.github_owner}/${repo}:pull_request"]
  deploy_subjects = [for repo in var.repositories : "repo:${var.github_owner}/${repo}:environment:${var.deploy_environment}"]

  app_role_arns   = [for prefix in var.app_role_prefixes : "arn:aws:iam::${local.account_id}:role/${prefix}*"]
  app_policy_arns = [for prefix in var.app_role_prefixes : "arn:aws:iam::${local.account_id}:policy/${prefix}*"]

  github_role_arns = "arn:aws:iam::${local.account_id}:role/github-actions-*"
  state_arn        = "arn:aws:s3:::${var.state_bucket}"
}

# --- GitHub OIDC provider ---------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "trust" {
  for_each = {
    plan   = local.plan_subjects
    deploy = local.deploy_subjects
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = each.value
    }
  }
}

# --- Boundary for every role an app creates ---------------------------------------

# The ceiling for app roles (ECS task and execution roles, service roles for data
# pipelines). Whatever policies an app attaches, its roles can never do more than this,
# and never anything in IAM.
data "aws_iam_policy_document" "app_role_boundary" {
  # A boundary is a ceiling, not a grant: a role's effective permissions are the
  # intersection of its own (scoped) policies and this document. Broad service
  # wildcards are the point here; the IAM/account/state denies are the real limits.
  #checkov:skip=CKV_AWS_107:Ceiling only; app task roles need secret reads and ECR tokens.
  #checkov:skip=CKV_AWS_108:Ceiling only; data access is granted by each app's scoped policies.
  #checkov:skip=CKV_AWS_109:Ceiling only; all IAM actions are explicitly denied below.
  #checkov:skip=CKV_AWS_110:Ceiling only; IAM and sts:AssumeRole are explicitly denied below.
  #checkov:skip=CKV_AWS_111:Ceiling only; write access is granted by each app's scoped policies.
  #checkov:skip=CKV_AWS_356:Ceiling only; resources are restricted in each app's own policies.
  statement {
    sid = "AppServices"
    actions = [
      "athena:*",
      "cloudwatch:*",
      "dms:*",
      "ec2:Describe*",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecs:*",
      "firehose:*",
      "glue:*",
      "kafka:*",
      "kafka-cluster:*",
      "kinesis:*",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "lakeformation:GetDataAccess",
      "logs:*",
      "rds:Describe*",
      "rds-db:connect",
      "s3:*",
      "s3tables:*",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "NeverIdentityOrAccount"
    effect    = "Deny"
    actions   = ["iam:*", "organizations:*", "account:*", "sts:AssumeRole"]
    resources = ["*"]
  }

  statement {
    sid       = "NeverTerraformState"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [local.state_arn, "${local.state_arn}/*"]
  }
}

resource "aws_iam_policy" "app_role_boundary" {
  name        = "app-role-boundary"
  description = "Permissions boundary required on every IAM role created by app pipelines"
  policy      = data.aws_iam_policy_document.app_role_boundary.json
}

# --- Plan role: pull requests, read-only ------------------------------------------

data "aws_iam_policy_document" "plan_state" {
  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_arn}/*"]
  }

  # use_lockfile writes a <key>.tflock object next to the state, even for plan.
  statement {
    sid       = "LockState"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/*.tflock"]
  }
}

resource "aws_iam_role" "plan" {
  #checkov:skip=CKV2_CUSTOM_1:Pipeline role, not an app role; it is the one defining the boundary and only this local stack manages it.
  name                 = "github-actions-terraform-plan"
  description          = "Terraform plan from pull requests in ${join(", ", var.repositories)}"
  assume_role_policy   = data.aws_iam_policy_document.trust["plan"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

# --- Deploy role: GitHub Environment "prod", needs your approval -------------------

data "aws_iam_policy_document" "deploy_state" {
  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }

  statement {
    sid       = "ReadWriteState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/*"]
  }

  statement {
    sid       = "NeverBootstrapState"
    effect    = "Deny"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/bootstrap/*"]
  }
}

data "aws_iam_policy_document" "deploy_iam" {
  statement {
    sid       = "ReadIam"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  # Roles may only be created, or get policies, while carrying the app boundary.
  statement {
    sid = "BoundedRoleWrites"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
    ]
    resources = local.app_role_arns

    condition {
      test     = "ArnEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.app_role_boundary.arn]
    }
  }

  statement {
    sid = "ManageAppRoles"
    actions = [
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
    ]
    resources = local.app_role_arns
  }

  statement {
    sid = "ManageAppPolicies"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = local.app_policy_arns
  }

  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/aws-service-role/*"]
  }

  # Explicit denies: they win over anything above and over PowerUserAccess.
  statement {
    sid       = "NeverRemoveBoundary"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["*"]
  }

  statement {
    sid       = "NeverAnotherBoundary"
    effect    = "Deny"
    actions   = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
    resources = ["*"]

    condition {
      test     = "ArnNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.app_role_boundary.arn]
    }
  }

  statement {
    sid    = "NeverTouchTheBoundaryPolicy"
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = [aws_iam_policy.app_role_boundary.arn]
  }

  statement {
    sid    = "NeverTouchPipelineIdentity"
    effect = "Deny"
    actions = [
      "iam:Attach*",
      "iam:Create*",
      "iam:Delete*",
      "iam:Detach*",
      "iam:Put*",
      "iam:Tag*",
      "iam:Untag*",
      "iam:Update*",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
    ]
    resources = [
      local.github_role_arns,
      aws_iam_openid_connect_provider.github.arn,
    ]
  }

  statement {
    sid       = "NeverRepointPublishedArns"
    effect    = "Deny"
    actions   = ["ssm:PutParameter", "ssm:DeleteParameter", "ssm:DeleteParameters", "ssm:LabelParameterVersion"]
    resources = ["arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter${var.ssm_prefix}/*"]
  }
}

resource "aws_iam_role" "deploy" {
  #checkov:skip=CKV2_CUSTOM_1:Pipeline role, not an app role; its own policies cap it and only this local stack manages it.
  name                 = "github-actions-terraform-deploy"
  description          = "Terraform apply/destroy from the ${var.deploy_environment} environment in ${join(", ", var.repositories)}"
  assume_role_policy   = data.aws_iam_policy_document.trust["deploy"].json
  max_session_duration = 7200 # creating an RDS instance can take a while
}

resource "aws_iam_role_policy_attachment" "deploy_power_user" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy" "deploy_state" {
  name   = "terraform-state"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_state.json
}

resource "aws_iam_role_policy" "deploy_iam" {
  name   = "bounded-iam"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_iam.json
}

# --- Published for workflows and app repos ----------------------------------------

resource "aws_ssm_parameter" "iam" {
  for_each = {
    app_role_boundary_arn  = aws_iam_policy.app_role_boundary.arn
    github_plan_role_arn   = aws_iam_role.plan.arn
    github_deploy_role_arn = aws_iam_role.deploy.arn
  }
  #checkov:skip=CKV2_AWS_34:ARNs are not secrets.

  name  = "${var.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
}
