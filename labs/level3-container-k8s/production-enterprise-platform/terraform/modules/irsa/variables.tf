variable "environment" {
  type        = string
  description = "Tên môi trường triển khai (dev hoặc prod)"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace chứa ServiceAccount"
}

variable "service_account_name" {
  type        = string
  description = "Tên Kubernetes ServiceAccount được gán quyền"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN của S3 Bucket mà Role được phép truy cập"
}
