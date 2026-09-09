# ==============================================================================
# 1. IAM Role cho EKS Cluster (Control Plane)
# ==============================================================================

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ==============================================================================
# 2. IAM Role cho Worker Node Group
# ==============================================================================

data "aws_iam_policy_document" "node_group_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node_group" {
  name               = "${var.cluster_name}-node-group-role"
  assume_role_policy = data.aws_iam_policy_document.node_group_assume_role.json
}

# Danh sách các policy ARN bắt buộc cho worker node
locals {
  node_group_required_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}

# Dùng for_each để gắn nhiều policy một cách sạch sẽ
resource "aws_iam_role_policy_attachment" "node_group" {
  for_each = toset(local.node_group_required_policies)

  policy_arn = each.value
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_instance_profile" "node_group" {
  name = "${var.cluster_name}-node-instance-profile"
  role = aws_iam_role.node_group.name
}

