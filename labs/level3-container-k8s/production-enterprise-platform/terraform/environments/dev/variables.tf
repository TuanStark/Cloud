variable "region" {
  type        = string
  description = "AWS Region triển khai hạ tầng"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Tên môi trường triển khai"
  default     = "dev"
}

variable "cluster_name" {
  type        = string
  description = "Tên cụm EKS"
  default     = "ecommerce-dev"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace chứa ứng dụng"
  default     = "dev-ecommerce"
}

variable "service_account_name" {
  type        = string
  description = "Tên ServiceAccount được cấp quyền IRSA"
  default     = "order-backend-dev-sa"
}
