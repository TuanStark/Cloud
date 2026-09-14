# ==============================================================================
# 1. BẢNG ĐIỀU KHIỂN TẦNG BIÊN & TRUY CẬP INTERNET
# ==============================================================================
output "entrypoint_url" {
  description = "Địa chỉ HTTP công khai của toàn bộ hệ thống E-Commerce"
  value       = "http://${module.edge_waf_alb.alb_dns_name}"
}

output "waf_web_acl_id" {
  description = "ID của lá chắn AWS WAF v2"
  value       = module.edge_waf_alb.waf_web_acl_id
}

# ==============================================================================
# 2. LỆNH KẾT NỐI CỤM KUBERNETES EKS CHO KỸ SƯ SRE
# ==============================================================================
output "eks_cluster_name" {
  description = "Tên cụm EKS"
  value       = module.compute_eks.cluster_name
}

output "eks_connect_command" {
  description = "Lệnh cấu hình kubectl một chạm để kết nối tới cụm EKS"
  value       = "aws eks update-kubeconfig --name ${module.compute_eks.cluster_name} --region ${var.aws_region}"
}

# ==============================================================================
# 3. THÔNG SỐ KẾT NỐI TẦNG DỮ LIỆU CHO BACKEND MICROSERVICES
# ==============================================================================
output "database_writer_endpoint" {
  description = "Aurora PostgreSQL Writer Endpoint (Dành cho Order Service)"
  value       = module.data_layer.aurora_cluster_endpoint
}

output "database_reader_endpoint" {
  description = "Aurora PostgreSQL Reader Endpoint (Dành cho Product Catalog Query)"
  value       = module.data_layer.aurora_reader_endpoint
}

output "redis_primary_endpoint" {
  description = "Redis Cache Endpoint (Dành cho Flash Sale Inventory Lock)"
  value       = module.data_layer.redis_primary_endpoint
}

# ==============================================================================
# 4. THÔNG SỐ KẾT NỐI KAFKA CHO EVENT STREAMING WORKERS
# ==============================================================================
output "kafka_bootstrap_brokers_tls" {
  description = "Kafka Bootstrap Brokers TLS (Port 9094)"
  value       = module.streaming.msk_bootstrap_brokers_tls
}

output "kafka_bootstrap_brokers_plaintext" {
  description = "Kafka Bootstrap Brokers Plaintext (Port 9092)"
  value       = module.streaming.msk_bootstrap_brokers_plaintext
}
