variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet (gán NACL)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "bastion_cidr" {
  description = "CIDR block for Bastion host (SSH access)"
  type        = string
  default     = "192.168.100.0/24"   # Điều chỉnh theo môi trường thực tế
}