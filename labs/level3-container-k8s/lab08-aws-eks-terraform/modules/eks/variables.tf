variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.cluster_name))
    error_message = "Tên cluster chỉ được chứa chữ cái, số, gạch nối (-) hoặc gạch dưới (_)."
  }
}

variable "cluster_version" {
  type        = string
  description = "The version of the EKS cluster"
  default     = "1.30"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID không hợp lệ, chuỗi phải bắt đầu bằng 'vpc-'."
  }

}

variable "subnet_ids" {
  type        = list(string)
  description = "The list of private subnets for EKS worker nodes"

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS bắt buộc phải có tối thiểu 2 subnets trên 2 AZs khác nhau để đảm bảo tính sẵn sàng cao (High Availability)."
  }

}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "The list of node instance types for EKS worker nodes"
}

variable "scaling_config" {
  type = object({
    min_size     = number
    max_size     = number
    desired_size = number
  })
}

variable "tags" {
  description = "Tags áp dụng cho tất cả tài nguyên"
  type        = map(string)
  default     = {}
}
variable "enable_addons" {
  type        = bool
  description = "Bật/tắt cài đặt EKS Add-ons (tắt khi chạy trên emulator Floci do chưa hỗ trợ API Addon)"
  default     = false
}
