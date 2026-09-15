
# ==============================================================
# KHỐI 1: PHÂN QUYỀN IAM LEAST-PRIVILEGE CHO EKS CLUSTER & NODES
# ==============================================================

# 1. IAM Role cho EKS Control Plane (Master)
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# 2. IAM Role cho EKS Worker Nodes
resource "aws_iam_role" "nodes" {
  name = "${var.project_name}-${var.environment}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# BÍ KÍP SENIOR: Gắn SSM để debug node qua AWS Console mà KHÔNG CẦN mở port 22 SSH!
resource "aws_iam_role_policy_attachment" "nodes_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.nodes.name
}

# =============================================================
# KHỐI 2: EKS CLUSTER VỚI MÃ HÓA ETCD BẰNG KMS CMK & AUDIT LOGS
# =============================================================
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-eks"
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_app_subnet_ids # EKS nằm hoàn toàn ở Private Subnet
    endpoint_private_access = true                       # Giao tiếp nội bộ siêu tốc & an toàn
    endpoint_public_access  = true                       # Cho phép kỹ sư dùng kubectl từ máy tính
    security_group_ids      = [var.eks_nodes_security_group_id]
  }

  # TIÊU CHUẨN BẢO MẬT PCI-DSS: MÃ HÓA ETCD SECRETS BẰNG KMS CMK
  encryption_config {
    provider {
      key_arn = var.kms_key_arn # Dùng khóa KMS của Module 02
    }
    resources = ["secrets"]
  }

  # SRE OBSERVABILITY: BẬT ĐẦY ĐỦ 5 LOẠI AUDIT LOGS CỦA KUBERNETES VÀO CLOUDWATCH
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_controller
  ]

  tags = {
    Name                                                               = "${var.project_name}-${var.environment}-eks"
    "karpenter.sh/discovery"                                           = "${var.project_name}-${var.environment}-eks"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}-eks" = "owned"
  }

  lifecycle {
    ignore_changes = [encryption_config]
  }
}


# =============================================================
# KHỐI 3: OIDC IDENTITY PROVIDER (NỀN TẢNG CỦA ZERO-TRUST IRSA)
# =============================================================

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-irsa"
  }
}

# =============================================================
# KHỐI 4: SYSTEM MANAGED NODE GROUP (CHẠY CÁC DỊCH VỤ HỆ THỐNG CỐT LÕI)
# =============================================================
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-system-ng"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_app_subnet_ids

  instance_types = var.system_node_instance_types
  capacity_type  = "ON_DEMAND" # Node hệ thống luôn dùng On-Demand để đảm bảo độ ổn định tuyệt đối

  scaling_config {
    desired_size = var.system_node_desired_size
    min_size     = var.system_node_min_size
    max_size     = var.system_node_max_size
  }

  # CẬP NHẬT KHÔNG GIÁN ĐOẠN (ZERO-DOWNTIME ROLLING UPDATE)
  update_config {
    max_unavailable = 1 # Khi nâng cấp phiên bản K8s, chỉ nâng cấp lần lượt từng node một
  }

  labels = {
    role = "system"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-system-node"
  }
}
