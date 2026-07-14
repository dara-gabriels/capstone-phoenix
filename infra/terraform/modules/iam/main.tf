# ---------------------------------------------------------------------------
# GitHub Actions OIDC provider
# This is what lets GitHub Actions authenticate to AWS with a short-lived
# token instead of a long-lived access key stored as a GitHub secret. One
# provider per AWS account, shared across all repos/roles.
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---------------------------------------------------------------------------
# Trust policy: ONLY the infrastructure repo's main branch (for apply) and
# pull requests against it (for plan) can assume this role. A different
# repo, a different branch, or a fork's PR cannot - the `sub` claim is
# exact-matched, not wildcarded across all of ts-a-devops' repos.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "terraform_ci_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_infra_repo}:ref:refs/heads/main",
        "repo:${var.github_org}/${var.github_infra_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "terraform_ci" {
  name                 = "${var.project_name}-terraform-ci"
  assume_role_policy   = data.aws_iam_policy_document.terraform_ci_trust.json
  max_session_duration = 3600
}

# ---------------------------------------------------------------------------
# Permissions policy.
#
# HONEST TRADE-OFF: most EC2 API actions (RunInstances, DescribeInstances,
# CreateSecurityGroup, etc.) don't support fine-grained resource-level ARN
# restriction the way S3 or DynamoDB do - AWS's IAM resource-level
# permissions for EC2 are limited to a handful of actions (mainly
# RunInstances tag/type conditions). Scoping ec2:* to specific ARNs here
# would either be a no-op or silently break the exact `terraform apply`
# this role exists to run. So EC2/VPC/networking permissions are broad by
# necessity; what we DO scope tightly is everything that supports it:
# state bucket, lock table, and the OIDC role's own self-modification
# (explicitly denied, so a compromised CI run can't grant itself more
# access).
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "terraform_ci_permissions" {
  statement {
    sid    = "EC2AndNetworking"
    effect = "Allow"
    actions = [
      "ec2:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*",
    ]
  }

  statement {
    sid    = "TerraformLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.lock_table_name}",
    ]
  }

  statement {
    sid    = "DenySelfPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:AttachRolePolicy",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = [aws_iam_role.terraform_ci.arn]
  }
}

resource "aws_iam_role_policy" "terraform_ci" {
  name   = "${var.project_name}-terraform-ci-policy"
  role   = aws_iam_role.terraform_ci.id
  policy = data.aws_iam_policy_document.terraform_ci_permissions.json
}
