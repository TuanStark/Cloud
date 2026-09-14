output "entrypoint_url" {
  description = "Địa chỉ HTTP công khai của môi trường Dev"
  value       = "http://${module.edge_waf_alb.alb_dns_name}"
}

output "eks_cluster_name" {
  description = "Tên cụm EKS Dev"
  value       = module.compute_eks.cluster_name
}

output "eks_connect_command" {
  description = "Lệnh cấu hình kubectl kết nối cụm Dev"
  value       = "aws eks update-kubeconfig --name ${module.compute_eks.cluster_name} --region ${var.aws_region}"
}

output "database_writer_endpoint" {
  description = "Aurora PostgreSQL Writer Endpoint"
  value       = module.data_layer.aurora_cluster_endpoint
}

output "redis_primary_endpoint" {
  description = "Redis Cache Endpoint"
  value       = module.data_layer.redis_primary_endpoint
}

output "kafka_bootstrap_brokers_plaintext" {
  description = "Kafka Bootstrap Brokers Plaintext"
  value       = module.streaming.msk_bootstrap_brokers_plaintext
}
