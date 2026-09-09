# 1. Khối 1: Kích hoạt IAM OIDC Provider (Nền tảng của IRSA)
# Lấy chứng chỉ TLS Thumbprint của EKS OIDC Issuer
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Tạo OpenID Connect Provider trong IAM
resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-irsa"
  }
}

# 2. Khối 2: Cài đặt 3 Core Add-ons được AWS quản lý
locals {
  core_addons = [
    "vpc-cni",
    "coredns",
    "kube-proxy"
  ]
}

resource "aws_eks_addon" "core" {
  for_each = var.enable_addons ? toset(local.core_addons) : toset([])

  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.value

  # CoreDNS chỉ khởi động được sau khi Node Group đã sẵn sàng (có máy chủ để đặt Pod)
  depends_on = [
    aws_eks_node_group.this
  ]

  tags = {
    Name = "${var.cluster_name}-${each.value}"
  }
}
