variable "vpc_cidr" {
  description = "CIDR block cho VPC, ví dụ: '10.0.0.0/16'"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 1))
    error_message = "vpc_cidr phải là một CIDR block hợp lệ (ví dụ: '10.0.0.0/16')."
  }
}

variable "availability_zones" {
  description = "Danh sách các Availability Zone (AZ) muốn deploy, ví dụ: ['ap-southeast-1a', 'ap-southeast-1b']"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 1
    error_message = "Cần ít nhất 1 Availability Zone."
  }

  validation {
    condition     = alltrue([for az in var.availability_zones : can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]?$", az))])
    error_message = "Mỗi Availability Zone phải đúng định dạng AWS (ví dụ: ap-southeast-1a)."
  }
}

variable "public_subnet_cidrs" {
  description = "Danh sách CIDR cho các Public Subnet, mỗi CIDR tương ứng với một AZ"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Số lượng public_subnet_cidrs phải bằng số lượng availability_zones."
  }

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 1))])
    error_message = "Mỗi phần tử trong public_subnet_cidrs phải là một CIDR block hợp lệ."
  }
}

variable "private_subnet_cidrs" {
  description = "Danh sách CIDR cho các Private Subnet, mỗi CIDR tương ứng với một AZ"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "Số lượng private_subnet_cidrs phải bằng số lượng availability_zones."
  }

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 1))])
    error_message = "Mỗi phần tử trong private_subnet_cidrs phải là một CIDR block hợp lệ."
  }
}

variable "enable_nat_gateway" {
  description = "Bật/tắt NAT Gateway. Nếu true, sẽ tạo NAT Gateway ở các Public Subnet."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Nếu true, chỉ tạo một NAT Gateway duy nhất (tiết kiệm chi phí). Nếu false, tạo NAT Gateway ở mỗi AZ."
  type        = bool
  default     = false
}

variable "enable_s3_endpoint" {
  description = "Bật/tắt Gateway Endpoint cho S3 (miễn phí)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Map các tags dùng để gán cho tất cả tài nguyên (chuẩn doanh nghiệp)."
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Prefix dùng để đặt tên các tài nguyên (ví dụ: 'prod', 'staging')."
  type        = string
  default     = "vpc"
}

variable "allowed_s3_bucket" {
  description = "Tên bucket S3 cho phép truy cập (chỉ cho phép read/write bucket này)"
  type        = string
  default     = "tuanstark-production-data"
}
