variable "region" {
  type        = string
  description = "AWS Region triển khai hạ tầng"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Tên môi trường triển khai"
  default     = "prod"
}

variable "cluster_name" {
  type        = string
  description = "Tên cụm EKS Production"
  default     = "ecommerce-production"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace chứa ứng dụng"
  default     = "production-ecommerce"
}

variable "service_account_name" {
  type        = string
  description = "Tên ServiceAccount được cấp quyền IRSA"
  default     = "order-backend-sa"
}

variable "scaling_config" {
  description = "Cấu hình scaling cho node group (desired, min, max)"
  type = object({
    desired_size = number
    min_size     = number
    max_size     = number
  })
  default = {
    desired_size = 3
    min_size     = 2
    max_size     = 5
  }
}

variable "tags" {
  description = "Tags áp dụng cho tất cả tài nguyên"
  type        = map(string)
  default     = {}
}

