# 1. THÔNG SỐ ĐỊNH DANH CỤM
output "cluster_name" {
  description = "Tên của cụm Amazon EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_id" {
  description = "ID của cụm Amazon EKS"
  value       = aws_eks_cluster.main.id
}

# 2. CHỨNG THỰC & KẾT NỐI KUBECTL / HELM
output "cluster_endpoint" {
  description = "Kubernetes API Server Endpoint (Để kubectl và CI/CD kết nối)"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificate Authority (CA) dạng Base64 để xác thực TLS với K8s API"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security Group ID do EKS Control Plane tự động quản lý"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# 3. OIDC IDENTITY PROVIDER (DÀNH CHO IRSA ROLES)
output "oidc_provider_arn" {
  description = "ARN của OIDC Provider (Cực kỳ quan trọng: Dùng để cấp quyền AWS IAM cho Pods)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL của OIDC Issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# 4. NODE ROLE ARN (DÀNH CHO KARPENTER LAUNCH INSTANCES)
output "node_role_arn" {
  description = "IAM Role ARN của Worker Nodes (Karpenter dùng role này để spawn node mới)"
  value       = aws_iam_role.nodes.arn
}
