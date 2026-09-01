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

# =========================================
# NETWORK CIDR CONFIGURATION
# =========================================

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_a" {
  description = "Availability Zone cho AZ A"
  type        = string
  default     = "ap-southeast-1a"
}

variable "az_b" {
  description = "Availability Zone cho AZ B"
  type        = string
  default     = "ap-southeast-1b"
}

# Public Subnets (Tier 1)
variable "public_subnet_a_cidr" {
  description = "CIDR cho Public Subnet AZ-A"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR cho Public Subnet AZ-B"
  type        = string
  default     = "10.0.2.0/24"
}

# Private App Subnets (Tier 2)
variable "private_app_subnet_a_cidr" {
  description = "CIDR cho Private App Subnet AZ-A"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_app_subnet_b_cidr" {
  description = "CIDR cho Private App Subnet AZ-B"
  type        = string
  default     = "10.0.12.0/24"
}

# Database Subnets (Tier 3 - Isolated)
variable "database_subnet_a_cidr" {
  description = "CIDR cho Database Subnet AZ-A"
  type        = string
  default     = "10.0.21.0/24"
}

variable "database_subnet_b_cidr" {
  description = "CIDR cho Database Subnet AZ-B"
  type        = string
  default     = "10.0.22.0/24"
}