# KHỐI 1: TẠO MẬT KHẨU NGẪU NHIÊN BẢO MẬT (RANDOM PASSWORD)
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "redis_auth_token" {
  length  = 32
  special = false # Redis auth token nên dùng chữ và số để tránh lỗi URL parsing
}

# KHỐI 2: CỤM AMAZON AURORA POSTGRESQL MULTI-AZ (STORAGE FLEET)
# 1. Cụm Cluster (Bộ lưu trữ phân tán 6 bản sao trên 3 AZs)
resource "aws_rds_cluster" "aurora" {
  cluster_identifier     = "${var.project_name}-${var.environment}-aurora-cluster"
  engine                 = "aurora-postgresql"
  engine_version         = "16.1"
  database_name          = var.database_name
  master_username        = var.master_username
  master_password        = random_password.db_password.result
  db_subnet_group_name   = var.aurora_subnet_group_name
  vpc_security_group_ids = [var.aurora_security_group_id]
  # BẢO MẬT & MÃ HÓA
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn
  # ĐỘ SẴN SÀNG CAO & SAO LƯU
  backup_retention_period = 7
  preferred_backup_window = "02:00-03:00"
  skip_final_snapshot     = true
  deletion_protection     = false # Trên Prod thật thì bật true để chống xóa nhầm
  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-cluster"
  }
}

# 2. Các Instance Máy Chủ (1 Writer + 2 Readers trải trên 3 AZs)
resource "aws_rds_cluster_instance" "instances" {
  count               = var.aurora_replica_count + 1 # 2 Readers + 1 Writer = 3 Instances
  identifier          = "${var.project_name}-${var.environment}-aurora-instance-${count.index + 1}"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = var.aurora_instance_class
  engine              = aws_rds_cluster.aurora.engine
  engine_version      = aws_rds_cluster.aurora.engine_version
  publicly_accessible = false
  availability_zone   = var.availability_zones[count.index]
  # Performance Insights (Giám sát tải câu lệnh SQL chi tiết)
  performance_insights_enabled = true
  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-instance-${count.index + 1}"
    Role = count.index == 0 ? "writer" : "reader"
  }
}

# KHỐI 3: ELASTICACHE REDIS REPLICATION GROUP (MULTI-AZ AUTO FAILOVER)
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "Multi-AZ Redis Cluster for Flash Sale Session and Hot Inventory"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.redis_node_type
  port           = 6379

  subnet_group_name  = var.redis_subnet_group_name
  security_group_ids = [var.redis_security_group_id]

  # MULTI-AZ & TỰ ĐỘNG CHUYỂN VÙNG DỰ PHÒNG
  automatic_failover_enabled = true
  multi_az_enabled           = true
  num_cache_clusters         = var.redis_replica_count + 1 # 1 Primary + 2 Replicas

  # BẢO MẬT TOÀN DIỆN
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-cluster"
  }
}
