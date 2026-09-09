output "s3_bucket_name" {
  description = "Tên S3 Bucket lưu hóa đơn môi trường Dev"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN của S3 Bucket môi trường Dev"
  value       = module.s3.bucket_arn
}

output "irsa_role_arn" {
  description = "ARN của IAM Role để gắn vào ServiceAccount Dev"
  value       = module.irsa.role_arn
}

output "cluster_name" {
  description = "Tên của cụm EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint kết nối vào Kubernetes API Server"
  value       = module.eks.cluster_endpoint
}

output "node_group_arn" {
  description = "ARN của EKS managed node group"
  value       = module.eks.node_group_arn
}

