variable "environment" {
  type        = string
  description = "Tên môi trường (dev hoặc prod)"
}

variable "force_destroy" {
  type        = bool
  description = "Cho phép xóa sạch bucket khi chạy terraform destroy"
  default     = false
}

variable "enable_lifecycle_archive" {
  type        = bool
  description = "Kích hoạt chuyển tầng lưu trữ sang Standard-IA và Glacier"
  default     = true
}
