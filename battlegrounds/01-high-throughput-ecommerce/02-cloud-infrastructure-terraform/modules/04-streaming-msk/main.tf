# KHỐI 1: CLOUDWATCH LOG GROUP (GIÁM SÁT BROKER)
resource "aws_cloudwatch_log_group" "msk" {
  count             = var.enable_msk ? 1 : 0
  name              = "/aws/msk/${var.project_name}-${var.environment}-kafka"
  retention_in_days = 7 # FinOps: Giữ log 7 ngày để tối ưu chi phí CloudWatch

  tags = {
    Name = "${var.project_name}-${var.environment}-msk-logs"
  }
}

# KHỐI 2: MSK SERVER PROPERTIES CONFIGURATION (TINH CHỈNH NHÂN KAFKA)
resource "aws_msk_configuration" "kafka" {
  count             = var.enable_msk ? 1 : 0
  name              = "${var.project_name}-${var.environment}-msk-config"
  kafka_versions    = [var.kafka_version]
  server_properties = <<EOF
auto.create.topics.enable = true
default.replication.factor = 3
min.insync.replicas = 2
num.partitions = 3
EOF
}

# KHỐI 3: AMAZON MSK CLUSTER (3 BROKERS TRÊN 3 AZs)
resource "aws_msk_cluster" "kafka" {
  count                  = var.enable_msk ? 1 : 0
  cluster_name           = "${var.project_name}-${var.environment}-msk"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = 3 # 1 Broker cho MỖI AZ (Tổng cộng 3 AZs)

  # CẤU HÌNH BROKER VÀ MẠNG
  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids # 3 Subnets từ Module 01
    security_groups = [var.msk_security_group_id]

    storage_info {
      ebs_storage_info {
        volume_size = var.ebs_volume_size
      }
    }
  }

  # BẢO MẬT & MÃ HÓA
  encryption_info {
    encryption_at_rest_kms_key_arn = var.kms_key_arn # Mã hóa ổ đĩa bằng KMS CMK

    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT" # Hỗ trợ cả TLS và Plaintext nội bộ VPC
      in_cluster    = true            # BẮT BUỘC: Mã hóa TLS giữa các Broker khi truyền qua các AZ
    }
  }

  # GẮN CẤU HÌNH TÙY BIẾN
  configuration_info {
    arn      = aws_msk_configuration.kafka[0].arn
    revision = aws_msk_configuration.kafka[0].latest_revision
  }

  # GẮN LOGGING
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk[0].name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-msk-cluster"
  }
}

