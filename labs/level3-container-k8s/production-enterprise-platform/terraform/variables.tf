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
