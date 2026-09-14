# ==============================================================================
# MODULE 01: TẦNG NỀN TẢNG MẠNG DEV (DẢI MẠNG 10.10.0.0/16 - SINGLE NAT FINOPS)
# ==============================================================================
module "networking" {
  source = "../../modules/01-networking-vpc"

  project_name     = var.project_name
  environment      = var.environment
  eks_cluster_name = "${var.project_name}-${var.environment}-eks"

  # Phân tách dải mạng để tránh trùng lặp với Prod (10.0.0.0/16)
  vpc_cidr                 = "10.10.0.0/16"
  public_subnet_cidrs      = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  private_app_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  isolated_db_subnet_cidrs = ["10.10.21.0/24", "10.10.22.0/24", "10.10.23.0/24"]

  # Tiết kiệm chi phí tối đa cho môi trường Dev: Chỉ tạo 1 NAT Gateway duy nhất
  single_nat_gateway = true
}

# ==============================================================================
# MODULE 02: TẦNG BẢO MẬT & MÃ HÓA (KMS CMK & SECURITY GROUP CHAINING)
# ==============================================================================
module "security" {
  source = "../../modules/02-security-kms-iam"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
}

# ==============================================================================
# MODULE 03: TẦNG DỮ LIỆU DEV (CẤU HÌNH TIẾT KIỆM TÀI NGUYÊN)
# ==============================================================================
module "data_layer" {
  source = "../../modules/03-data-aurora-redis"

  project_name             = var.project_name
  environment              = var.environment
  aurora_subnet_group_name = module.networking.aurora_subnet_group_name
  redis_subnet_group_name  = module.networking.redis_subnet_group_name
  kms_key_arn              = module.security.kms_key_arn
  aurora_security_group_id = module.security.aurora_security_group_id
  redis_security_group_id  = module.security.redis_security_group_id

  # Sizing tinh gọn cho Dev
  aurora_instance_class = "db.t4g.medium"
  aurora_replica_count  = 1 # Dev chỉ cần 1 Reader
  redis_node_type       = "cache.t4g.medium"
  redis_replica_count   = 1 # Dev chỉ cần 1 replica
}

# ==============================================================================
# MODULE 04: TẦNG HÀNG ĐỢI SỰ KIỆN TẢI CAO (AMAZON MSK APACHE KAFKA)
# ==============================================================================
module "streaming" {
  source = "../../modules/04-streaming-msk"

  project_name          = var.project_name
  environment           = var.environment
  subnet_ids            = module.networking.isolated_db_subnet_ids
  kms_key_arn           = module.security.kms_key_arn
  msk_security_group_id = module.security.msk_security_group_id

  ebs_volume_size = 20 # Giảm từ 50GB xuống 20GB để tiết kiệm storage
}

# ==============================================================================
# MODULE 05: TẦNG TÍNH TOÁN CONTAINER DEV (AMAZON EKS v1.30)
# ==============================================================================
module "compute_eks" {
  source = "../../modules/05-compute-eks"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  private_app_subnet_ids      = module.networking.private_app_subnet_ids
  kms_key_arn                 = module.security.kms_key_arn
  eks_nodes_security_group_id = module.security.eks_nodes_security_group_id

  # Dev node group quy mô tối thiểu
  system_node_min_size     = 1
  system_node_max_size     = 2
  system_node_desired_size = 1
}

# ==============================================================================
# MODULE 06: TẦNG BIÊN & PHÒNG THỦ L7 (AWS WAF v2 + APPLICATION LOAD BALANCER)
# ==============================================================================
module "edge_waf_alb" {
  source = "../../modules/06-edge-waf-alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id

  # Cho phép ngưỡng rate limit cao hơn ở Dev để các lập trình viên test API thoải mái
  waf_rate_limit = 1000
}
