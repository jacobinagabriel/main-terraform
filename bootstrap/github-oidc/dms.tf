# --- Account-level DMS roles ------------------------------------------------------
# AWS DMS looks these two roles up by their fixed names (one per account), so an app
# pipeline can't create them: the deploy role may only create roles with an app prefix.
# They carry AWS's managed policies for DMS only.

locals {
  dms_roles = {
    "dms-vpc-role"             = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
    "dms-cloudwatch-logs-role" = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  }
}

data "aws_iam_policy_document" "dms_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dms" {
  for_each = local.dms_roles
  #checkov:skip=CKV2_CUSTOM_1:AWS service role with a fixed name and an AWS managed policy; not an app role.

  name               = each.key
  description        = "Required by AWS DMS (fixed name, one per account)"
  assume_role_policy = data.aws_iam_policy_document.dms_trust.json
}

resource "aws_iam_role_policy_attachment" "dms" {
  for_each = local.dms_roles

  role       = aws_iam_role.dms[each.key].name
  policy_arn = each.value
}
