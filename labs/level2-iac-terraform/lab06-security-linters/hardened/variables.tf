variable "aws_region" {
  description = "AWS Region deploy hạ tầng"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Tên môi trường triển khai"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "Dải CIDR mạng nội bộ của VPC (hoặc VPN subnet)"
  type        = string
  default     = "10.0.0.0/16"
}
