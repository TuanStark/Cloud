# ==============================================================================
# 1. Tài nguyên 1: Khuôn mẫu bảo mật
# ==============================================================================
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-lt-"
  description = "Custom launch template for EKS ${var.cluster_name} hardened worker nodes"

  # Bắt buộc mã hóa ổ cứng Root At-Rest
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Triệt tiêu lỗ hổng SSRF bằng IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Bắt buộc token IMDSv2
    http_put_response_hop_limit = 2          # Bắt buộc bằng 2 để Pods chạy trong overlay network có thể lấy token
  }

  # Gắn Node Security Group đã tạo ở security_groups.tf
  vpc_security_group_ids = [aws_security_group.node.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# 2. Tài nguyên 2: Quản lý nhóm Worker Node
# ==============================================================================
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-default-ng"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids # Chạy hoàn toàn trong Private Subnets!

  # Kẹp Launch Template đã hardened ở trên vào Node Group
  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.scaling_config.desired_size
    min_size     = var.scaling_config.min_size
    max_size     = var.scaling_config.max_size
  }

  # Bắt buộc đợi toàn bộ 3 IAM Policy gắn xong mới tạo Node Group
  depends_on = [
    aws_iam_role_policy_attachment.node_group
  ]

  tags = {
    Name = "${var.cluster_name}-default-ng"
  }
}

# ==============================================================================
# 3. Tài nguyên 3: Tự động khởi chạy Worker Node Instances (EC2 thực tế)
# ==============================================================================
resource "aws_instance" "workers" {
  count         = var.scaling_config.desired_size
  ami           = "ami-0abcdef1234567890" # Amazon Linux 2 EKS AMI
  instance_type = var.node_instance_types[0]
  subnet_id     = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.node.id]
  iam_instance_profile   = aws_iam_instance_profile.node_group.name

  tags = {
    Name                                        = "${var.cluster_name}-worker-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "eks:nodegroup-name"                        = "${var.cluster_name}-default-ng"
  }
}

