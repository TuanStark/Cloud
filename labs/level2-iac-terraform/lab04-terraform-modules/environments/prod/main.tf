module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # Cấu hình tiết kiệm tiền cho Dev:
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway
  enable_s3_endpoint = true
  allowed_s3_bucket  = var.allowed_s3_bucket

  tags = var.tags
}

