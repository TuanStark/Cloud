variable "aws_region" {
  description = "AWS Region deploy hạ tầng"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Tên môi trường"
  type        = string
  default     = "dev"
}

# Biến này cố tình khai báo nhưng KHÔNG sử dụng trong code
# TFLint sẽ phát hiện lỗi dead code này (terraform_unused_declarations)
variable "unused_variable_db_password" {
  description = "Biến rác không được sử dụng"
  type        = string
  default     = "SuperSecretPassword123!"
}
