variable "name_prefix" {
  description = "Prefix cho tên các resource (dùng để phân biệt môi trường)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
}

variable "availability_zones" {
  description = "Danh sách các Availability Zone sử dụng"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks cho các Public Subnet"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks cho các Private Subnet"
  type        = list(string)
}

variable "allowed_s3_bucket" {
  description = "Tên S3 bucket được phép truy cập qua VPC Endpoint"
  type        = string
  default     = "my-company-dev-bucket" # Thay bằng bucket thực tế của bạn
}

variable "single_nat_gateway" {
  description = "Nếu true, chỉ tạo một NAT Gateway duy nhất (tiết kiệm chi phí). Nếu false, tạo NAT Gateway ở mỗi AZ (High Availability)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Các tag chung cho tất cả resource"
  type        = map(string)
  default     = {}
}

