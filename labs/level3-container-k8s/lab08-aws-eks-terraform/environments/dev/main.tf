module "eks" {
  source = "../../modules/eks"

  cluster_name = var.cluster_name
  vpc_id       = aws_vpc.this.id
  subnet_ids   = aws_subnet.private[*].id

  # Cấu hình scaling cho node group – lấy từ biến đầu vào
  scaling_config = var.scaling_config

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

