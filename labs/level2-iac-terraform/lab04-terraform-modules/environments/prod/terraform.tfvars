name_prefix = "prod"
vpc_cidr    = "10.20.0.0/16"

availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

public_subnet_cidrs  = ["10.20.101.0/24", "10.20.102.0/24"]
private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]

allowed_s3_bucket = "my-company-prod-bucket"

tags = {
  Environment = "prod"
  Criticality = "high"
  CostCenter  = "Core-Platform"
  ManagedBy   = "terraform"
}
