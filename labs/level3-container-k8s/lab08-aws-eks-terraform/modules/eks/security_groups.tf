# 1. Security Group cho Control Plane
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane communication"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow cluster control plane to communicate with worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}
# 2. Security Group cho Worker Nodes
resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for all nodes in the EKS cluster"
  vpc_id      = var.vpc_id

  # Ingress nội bộ (Node-to-Node): Cho phép các Worker Node 
  # trong cùng Security Group nói chuyện với nhau (Node-to-Node traffic):
  ingress {
    description = "Allow node to communicate with each other"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true # CỰC KỲ QUAN TRỌNG: Chỉ cho phép traffic từ chính SG này!
  }

  # Ingress từ Control Plane: Cho phép Control Plane gọi xuống Kubelet (port 10250) và Ingress Pods:
  ingress {
    description     = "Allow control plane to communicate with worker nodes"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id] # Chỉ cho phép từ Cluster SG!
  }

  egress {
    description = "Allow node to communicate with the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                        = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# 3. Rule cho phép Worker Nodes giao tiếp với Control Plane qua port 443 (API Server)
# Dùng resource riêng biệt để tránh lỗi vòng lặp phụ thuộc (dependency cycle) giữa 2 SG
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow worker nodes to communicate with cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

