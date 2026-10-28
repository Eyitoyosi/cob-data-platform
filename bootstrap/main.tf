data "aws_caller_identity" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  subject_prefix = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}"
  oidc_host      = "token.actions.githubusercontent.com"
}

# 1. Tell AWS to trust GitHub as an identity provider (once per account)
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# 2. Trust policies: WHO may assume each role
data "aws_iam_policy_document" "plan_trust" {
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

    # Pull requests, and runs on main. Never anything else.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values = [
        "${local.subject_prefix}:pull_request",
        "${local.subject_prefix}:ref:refs/heads/main",
      ]
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  for_each = toset(var.environments)

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

    # Only a job that runs inside this GitHub environment.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.subject_prefix}:environment:${each.key}"]
    }
  }
}

# 3. The roles. Named gha-*, NOT cob-*, so the apply role's own IAM
#    permissions (scoped to cob-*) can never touch the pipeline's roles.
resource "aws_iam_role" "plan" {
  for_each           = toset(var.environments)
  name               = "gha-data-platform-${each.key}-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role" "apply" {
  for_each           = toset(var.environments)
  name               = "gha-data-platform-${each.key}-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust[each.key].json
}

# 4. Permissions: WHAT each role can do
data "aws_iam_policy_document" "read" {
  for_each = toset(var.environments)

  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }

  statement {
    sid       = "StateRead"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/data-platform/${each.key}/*"]
  }

  statement {
    sid       = "StateLock"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.lock_table}"]
  }

  statement {
    sid     = "ReadDataLakeBuckets"
    actions = ["s3:Get*", "s3:List*"]
    resources = [
      "arn:aws:s3:::cob-${each.key}-${var.data_lake_name}-*",
      "arn:aws:s3:::cob-${each.key}-${var.data_lake_name}-*/*",
    ]
  }

  statement {
    sid = "ReadGlueAndAthena"
    actions = [
      "glue:Get*", "glue:List*", "glue:BatchGet*",
      "athena:Get*", "athena:List*", "athena:BatchGet*",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ReadDataLakeIam"
    actions = ["iam:Get*", "iam:List*"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/cob-${each.key}-${var.data_lake_name}-*",
      "arn:aws:iam::${local.account_id}:policy/cob-${each.key}-${var.data_lake_name}-*",
    ]
  }
}

data "aws_iam_policy_document" "write" {
  for_each = toset(var.environments)

  statement {
    sid       = "StateWrite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/data-platform/${each.key}/*"]
  }

  statement {
    sid     = "ManageDataLakeBuckets"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::cob-${each.key}-${var.data_lake_name}-*",
      "arn:aws:s3:::cob-${each.key}-${var.data_lake_name}-*/*",
    ]
  }

  statement {
    sid       = "ManageGlueAndAthena"
    actions   = ["glue:*", "athena:*"]
    resources = ["*"]
  }

  statement {
    sid = "ManageDataLakeIam"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
      "iam:TagRole", "iam:UntagRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
      "iam:TagPolicy", "iam:UntagPolicy",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/cob-${each.key}-${var.data_lake_name}-*",
      "arn:aws:iam::${local.account_id}:policy/cob-${each.key}-${var.data_lake_name}-*",
    ]
  }

  statement {
    sid       = "PassCrawlerRoleToGlue"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/cob-${each.key}-${var.data_lake_name}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "plan_read" {
  for_each = toset(var.environments)
  name     = "read"
  role     = aws_iam_role.plan[each.key].id
  policy   = data.aws_iam_policy_document.read[each.key].json
}

resource "aws_iam_role_policy" "apply_read" {
  for_each = toset(var.environments)
  name     = "read"
  role     = aws_iam_role.apply[each.key].id
  policy   = data.aws_iam_policy_document.read[each.key].json
}

resource "aws_iam_role_policy" "apply_write" {
  for_each = toset(var.environments)
  name     = "write"
  role     = aws_iam_role.apply[each.key].id
  policy   = data.aws_iam_policy_document.write[each.key].json
}