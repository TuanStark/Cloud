module "s3" {
  source = "../../modules/s3-invoice"

  environment              = var.environment
  force_destroy            = true  # Dev cho phép xóa sạch bucket khi dọn dẹp
  enable_lifecycle_archive = false # Dev không cần nén Glacier để tối ưu tốc độ test
}

module "irsa" {
  source = "../../modules/irsa"

  environment          = var.environment
  region               = var.region
  namespace            = var.namespace
  service_account_name = var.service_account_name
  s3_bucket_arn        = module.s3.bucket_arn
}
