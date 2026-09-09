output "cluster_id" {
  description = "Tên ID của cụm EKS"
  value       = aws_eks_cluster.this.id
}

output "cluster_endpoint" {
  description = "Endpoint kết nối vào Kubernetes API Server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Chứng chỉ số Base64 của cụm EKS (phục vụ cấu hình kubeconfig/helm)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security Group ID của Control Plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security Group ID của Worker Nodes"
  value       = aws_security_group.node.id
}

output "oidc_provider_arn" {
  description = "ARN của IAM OIDC Provider phục vụ cấu hình IRSA cho Pods"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "cluster_name" {
  description = "Tên của cụm EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "node_group_arn" {
  description = "ARN của EKS managed node group"
  value       = aws_eks_node_group.this.arn
}

