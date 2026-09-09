module "eks" {
  source = "../../modules/eks"

  cluster_name   = var.cluster_name
  vpc_id         = aws_vpc.this.id
  subnet_ids     = aws_subnet.private[*].id
  scaling_config = var.scaling_config
  enable_addons  = false # Floci chưa hỗ trợ EKS Addon API

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

module "s3" {
  source = "../../modules/s3-invoice"

  environment              = var.environment
  force_destroy            = false # Prod cấm tuyệt đối việc xóa nhầm bucket
  enable_lifecycle_archive = true  # Prod bật lưu trữ Glacier dài hạn tối ưu FinOps
}

module "irsa" {
  source = "../../modules/irsa"

  environment          = var.environment
  region               = var.region
  namespace            = var.namespace
  service_account_name = var.service_account_name
  s3_bucket_arn        = module.s3.bucket_arn
}
