data "aws_caller_identity" "current" {}

# Nếu chạy trên AWS thật, ta có thể query trực tiếp cluster:
# data "aws_eks_cluster" "this" { name = var.cluster_name }
# Nhưng để linh hoạt cho cả Floci / Local, ta có thể tạo local variable tính toán OIDC ARN:
locals {
  account_id = data.aws_caller_identity.current.account_id
  # Giả định OIDC Issuer URL của cụm EKS từ Lab 08
  oidc_issuer       = "oidc.eks.${var.region}.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  oidc_provider_arn = "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_issuer}"
}

# 2.Tạo IAM Policy Document cho Trust Relationship (Assume Role)
data "aws_iam_policy_document" "irsa_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
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

# 3.Tạo IAM Policy Document cho quyền truy cập S3 (Least Privilege)
data "aws_iam_policy_document" "s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.order_data.arn,
      "${aws_s3_bucket.order_data.arn}/*",
    ]
  }
}

# 4.Tạo IAM Role & Gắn Policy
resource "aws_iam_role" "order_irsa" {
  name               = "order-irsa-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
}

resource "aws_iam_role_policy" "order_s3" {
  name   = "order-s3-access-${var.environment}"
  role   = aws_iam_role.order_irsa.id
  policy = data.aws_iam_policy_document.s3_access.json
}
