name_prefix = "dev"
vpc_cidr    = "10.10.0.0/16"

availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

public_subnet_cidrs  = ["10.10.101.0/24", "10.10.102.0/24"]
private_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]

allowed_s3_bucket = "my-company-dev-bucket" # 👈 Đổi thành bucket thật
single_nat_gateway = true

tags = {
  Environment = "dev"
  CostCenter  = "Engineering"
  Project     = "finops-optimization"
  ManagedBy   = "terraform"
}
