variable "project_name" {
  type        = string
  description = "Tên định danh dự án (ví dụ: ecommerce, fintech)"
  default     = "ecommerce"
}

variable "environment" {
  type        = string
  description = "Môi trường triển khai (production, staging, dev)"
  default     = "production"
}

variable "vpc_cidr" {
  description = "Dải địa chỉ IP chính của VPC (CIDR block, chuẩn /16 = 65,536 IPs)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR phải là một định dạng dải IP hợp lệ (ví dụ: 10.0.0.0/16)."
  }
}

variable "availability_zones" {
  description = "Danh sách tối thiểu 3 Availability Zones để đảm bảo High Availability"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) >= 3
    error_message = "Hạ tầng chuẩn Enterprise bắt buộc phải phân bổ trên tối thiểu 3 Availability Zones!"
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Danh sách các dải IP Public Subnet (thường là /24)"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Số lượng Public Subnet phải bằng số lượng AZ!"
  }
}

variable "isolated_db_subnet_cidrs" {
  type        = list(string)
  description = "Danh sách các dải IP Isolated Subnet (riêng tư, không ra Internet)"
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  validation {
    condition     = length(var.isolated_db_subnet_cidrs) == length(var.availability_zones)
    error_message = "Số lượng Database Subnet phải bằng số lượng AZ!"
  }
}

variable "single_nat_gateway" {
  description = "Sử dụng 1 NAT Gateway duy nhất cho toàn bộ VPC (Cost Optimization cho Production)"
  type        = bool
  default     = false
}

# BỔ SUNG 1: TẦNG 2 - PRIVATE APP SUBNETS (CHO EKS NODES)
variable "private_app_subnet_cidrs" {
  type        = list(string)
  description = "Danh sách CIDR cho 3 Private App Subnets (Dành cho EKS Worker Nodes & Pods)"
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  validation {
    condition     = length(var.private_app_subnet_cidrs) == length(var.availability_zones)
    error_message = "Số lượng Private App Subnet phải bằng số lượng AZ!"
  }
}

# BỔ SUNG 2: TÊN EKS CLUSTER ĐỂ GẮN TAG AUTO-DISCOVERY
variable "eks_cluster_name" {
  type        = string
  description = "Tên cụm EKS dùng để gắn tag tự động nhận diện Subnet cho AWS Load Balancer Controller và Karpenter"
  default     = "ecommerce-prod-eks"
}

variable "enable_elasticache" {
  type        = bool
  default     = false
  description = "Bật/tắt ElastiCache Subnet Group (tắt khi dùng Floci do chưa hỗ trợ CreateCacheSubnetGroup)"
}
