variable "region" {
  description = "AWS region để deploy"
  type        = string
  default     = "ap-southeast-1"
}

variable "access_key" {
  description = "AWS Access Key"
  type        = string
  default     = "test"
}

variable "secret_key" {
  description = "AWS Secret Key"
  type        = string
  default     = "test"
}

variable "endpoint_ec2" {
  description = "Endpoint URL cho dịch vụ EC2"
  type        = string
  default     = "https://chungkhoanai.dpdns.org"
}

variable "skip_creds_validation" {
  description = "Bỏ qua kiểm tra xác thực"
  type        = bool
  default     = true
}

variable "skip_requesting_account_id" {
  description = "Bỏ qua lấy account ID"
  type        = bool
  default     = true
}

variable "skip_metadata_api_check" {
  description = "Bỏ qua kiểm tra metadata API"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "CIDR cho Public Subnet A"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR cho Public Subnet B"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR for private subnet A"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR for private subnet B"
  type        = string
  default     = "10.0.12.0/24"
}

variable "private_subnet_database_cidr" {
  description = "CIDR for private subnet Database"
  type        = string
  default     = "10.0.21.0/24"
}

variable "private_subnet_database_b_cidr" {
  description = "CIDR for private subnet Database B"
  type        = string
  default     = "10.0.22.0/24"
}

variable "az_a" {
  description = "Availability Zone cho Subnet A"
  type        = string
  default     = "ap-southeast-1a"
}

variable "az_b" {
  description = "Availability Zone cho Subnet B"
  type        = string
  default     = "ap-southeast-1b"
}