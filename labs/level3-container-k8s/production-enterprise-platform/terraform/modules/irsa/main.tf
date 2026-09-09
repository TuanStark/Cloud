data "aws_caller_identity" "current" {}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  oidc_issuer       = "oidc.eks.${var.region}.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  oidc_provider_arn = "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_issuer}"
}

# Trust Policy: Chỉ cho phép ServiceAccount chỉ định trong đúng Namespace assume role
data "aws_iam_policy_document" "irsa_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Least Privilege Policy: Chỉ cho phép thao tác trên đúng S3 Bucket của môi trường đó
data "aws_iam_policy_document" "s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role" "this" {
  name               = "ecommerce-backend-irsa-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json

  tags = {
    Environment = var.environment
    Service     = "OrderBackend"
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "ecommerce-s3-access-${var.environment}"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.s3_access.json
}
