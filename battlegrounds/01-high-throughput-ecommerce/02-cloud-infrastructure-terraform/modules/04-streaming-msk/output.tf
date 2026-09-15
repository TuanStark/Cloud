output "msk_cluster_arn" {
  description = "ARN của cụm Amazon MSK Cluster"
  value       = try(aws_msk_cluster.kafka[0].arn, "")
}

output "msk_bootstrap_brokers_tls" {
  description = "Danh sách địa chỉ Bootstrap Brokers qua cổng mã hóa TLS (Port 9094) - Chuẩn Production"
  value       = try(aws_msk_cluster.kafka[0].bootstrap_brokers_tls, "")
}

output "msk_bootstrap_brokers_plaintext" {
  description = "Danh sách địa chỉ Bootstrap Brokers qua cổng Plaintext (Port 9092) - Dùng cho nội bộ VPC"
  value       = try(aws_msk_cluster.kafka[0].bootstrap_brokers, "127.0.0.1:9092")
}

output "msk_zookeeper_connect_string" {
  description = "Chuỗi kết nối Zookeeper / Metadata quorum"
  value       = try(aws_msk_cluster.kafka[0].zookeeper_connect_string, "")
}

