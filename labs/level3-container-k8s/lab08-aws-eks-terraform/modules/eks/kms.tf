resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-cluster-kms-key"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/eks/${var.cluster_name}"
  target_key_id = aws_kms_key.eks.key_id
}
