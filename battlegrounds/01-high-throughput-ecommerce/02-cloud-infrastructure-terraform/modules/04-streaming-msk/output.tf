output "msk_cluster_arn" {
  description = "ARN của cụm Amazon MSK Cluster"
  value       = aws_msk_cluster.kafka.arn
}

output "msk_bootstrap_brokers_tls" {
  description = "Danh sách địa chỉ Bootstrap Brokers qua cổng mã hóa TLS (Port 9094) - Chuẩn Production"
  value       = aws_msk_cluster.kafka.bootstrap_brokers_tls
}

output "msk_bootstrap_brokers_plaintext" {
  description = "Danh sách địa chỉ Bootstrap Brokers qua cổng Plaintext (Port 9092) - Dùng cho nội bộ VPC"
  value       = aws_msk_cluster.kafka.bootstrap_brokers
}

output "msk_zookeeper_connect_string" {
  description = "Chuỗi kết nối Zookeeper / Metadata quorum"
  value       = aws_msk_cluster.kafka.zookeeper_connect_string
}
