# ==============================================================================
# MODULE 01: TẦNG NỀN TẢNG MẠNG (VPC MULTI-AZ, NAT GATEWAY, SUBNET GROUPS)
# ==============================================================================
module "networking" {
  source = "../../modules/01-networking-vpc"

  project_name     = var.project_name
  environment      = var.environment
  eks_cluster_name = "${var.project_name}-${var.environment}-eks"
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
# MODULE 03: TẦNG LƯU TRỮ DỮ LIỆU BỀN VỮNG (AURORA POSTGRESQL HA + REDIS CLUSTER)
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
}

# ==============================================================================
# MODULE 05: TẦNG TÍNH TOÁN CONTAINER (AMAZON EKS v1.30 & BOTTLEROCKET NODES)
# ==============================================================================
module "compute_eks" {
  source = "../../modules/05-compute-eks"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  private_app_subnet_ids      = module.networking.private_app_subnet_ids
  kms_key_arn                 = module.security.kms_key_arn
  eks_nodes_security_group_id = module.security.eks_nodes_security_group_id
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
}
