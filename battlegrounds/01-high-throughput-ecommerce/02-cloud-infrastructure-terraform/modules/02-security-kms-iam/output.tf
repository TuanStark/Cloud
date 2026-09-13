# 1. KHÓA MÃ HÓA KMS (Dùng cho Aurora, Redis, MSK, và EKS Secrets)
output "kms_key_arn" {
  description = "ARN của khóa KMS CMK dùng để mã hóa toàn bộ dữ liệu"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID của khóa KMS CMK"
  value       = aws_kms_key.main.key_id
}

# 2. SECURITY GROUP CHO LOAD BALANCER (Dùng cho Module 06)
output "alb_security_group_id" {
  description = "Security Group ID của Public ALB"
  value       = aws_security_group.alb.id
}

# 3. SECURITY GROUP CHO EKS WORKER NODES (Dùng cho Module 05)
output "eks_nodes_security_group_id" {
  description = "Security Group ID của EKS Nodes"
  value       = aws_security_group.eks_nodes.id
}

# 4. SECURITY GROUP CHO DATABASE AURORA (Dùng cho Module 03)
output "aurora_security_group_id" {
  description = "Security Group ID của Aurora PostgreSQL"
  value       = aws_security_group.aurora.id
}

# 5. SECURITY GROUP CHO REDIS (Dùng cho Module 03)
output "redis_security_group_id" {
  description = "Security Group ID của ElastiCache Redis"
  value       = aws_security_group.redis.id
}

# 6. SECURITY GROUP CHO MSK KAFKA (Dùng cho Module 04)
output "msk_security_group_id" {
  description = "Security Group ID của Amazon MSK"
  value       = aws_security_group.msk.id
}
