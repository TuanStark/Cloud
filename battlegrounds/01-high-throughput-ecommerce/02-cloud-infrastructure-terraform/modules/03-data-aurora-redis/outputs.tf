# ==============================================================================
# 1. THÔNG SỐ KẾT NỐI AMAZON AURORA POSTGRESQL
# ==============================================================================
output "aurora_cluster_endpoint" {
  description = "Writer Endpoint (Chỉ dùng cho lệnh Ghi INSERT/UPDATE đơn hàng)"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  description = "Reader Endpoint (Tự động cân bằng tải giữa 2 Readers cho lệnh Đọc SELECT)"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_database_name" {
  description = "Tên Database chính"
  value       = aws_rds_cluster.aurora.database_name
}

output "aurora_master_username" {
  description = "Tài khoản quản trị Database"
  value       = aws_rds_cluster.aurora.master_username
}

output "aurora_master_password" {
  description = "Mật khẩu quản trị Database (Được che giấu an toàn)"
  value       = random_password.db_password.result
  sensitive   = true # BẮT BUỘC: Chống in lộ mật khẩu ra màn hình terminal & CI/CD log
}

output "aurora_port" {
  description = "Cổng kết nối PostgreSQL"
  value       = aws_rds_cluster.aurora.port
}

# ==============================================================================
# 2. THÔNG SỐ KẾT NỐI AMAZON ELASTICACHE REDIS
# ==============================================================================
output "redis_primary_endpoint" {
  description = "Primary Endpoint của Redis (Dành cho ghi cache & trừ kho ảo)"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader Endpoint của Redis (Dành cho đọc cache sản phẩm)"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Cổng kết nối Redis"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_auth_token" {
  description = "Mật khẩu xác thực Redis AUTH"
  value       = random_password.redis_auth_token.result
  sensitive   = true # BẮT BUỘC: Che giấu token bảo mật
}
