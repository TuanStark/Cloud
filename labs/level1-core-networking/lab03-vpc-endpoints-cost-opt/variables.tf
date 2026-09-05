variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Số lượng Availability Zone (AZ) sử dụng"
  type        = number
  default     = 2
}

variable "private_subnet_cidrs" {
  description = "CIDR cho các private subnet (mỗi AZ một subnet)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR cho các public subnet (mỗi AZ một subnet)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "allowed_s3_bucket" {
  description = "Tên bucket S3 cho phép truy cập (chỉ cho phép read/write bucket này)"
  type        = string
  default     = "tuanstark-production-data"
}

variable "enable_nat_gateway" {
  description = "Bật NAT Gateway? (nếu false thì không tạo NAT, chỉ dùng VPC Endpoint và Internet Gateway cho public subnet)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Chỉ dùng một NAT Gateway duy nhất (tiết kiệm chi phí) hay mỗi AZ một NAT?"
  type        = bool
  default     = true
}
