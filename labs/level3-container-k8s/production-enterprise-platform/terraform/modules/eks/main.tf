resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true # Bắt buộc cho giao tiếp nội bộ trong VPC
    endpoint_public_access  = true # Cho phép gọi kubectl từ ngoài (có thể giới hạn CIDR)
  }

  # CIS Benchmark: Bắt buộc mã hóa etcd Secrets bằng AWS KMS
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  # CIS Benchmark: Bật toàn bộ 5 loại Control Plane Logs
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Chuẩn mới EKS 2026: Quản lý quyền qua API (Access Entries)
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Tránh lỗi eventual consistency của IAM
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]

  tags = {
    Name = var.cluster_name
  }
}
