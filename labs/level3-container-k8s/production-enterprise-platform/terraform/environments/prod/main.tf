module "s3" {
  source = "../../modules/s3-invoice"

  environment              = var.environment
  force_destroy            = false # Prod KHÔNG cho phép xóa bừa bãi
  enable_lifecycle_archive = true  # Prod bật tự động chuyển sang Standard-IA và Glacier sau 30/90 ngày
}

module "irsa" {
  source = "../../modules/irsa"

  environment          = var.environment
  region               = var.region
  namespace            = var.namespace
  service_account_name = var.service_account_name
  s3_bucket_arn        = module.s3.bucket_arn
}
