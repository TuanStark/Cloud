variable "project_name" {
  type    = string
  default = "ecommerce"
}

variable "environment" {
  type    = string
  default = "prod"
}

# Nhóm 2: Nhận từ Module 01 (VPC)
variable "aurora_subnet_group_name" {
  type = string
}

variable "redis_subnet_group_name" {
  type = string
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Nhóm 3: Nhận từ Module 02 (Security & KMS)
variable "kms_key_arn" {
  type = string
}

variable "aurora_security_group_id" {
  type = string
}

variable "redis_security_group_id" {
  type = string
}

# Nhóm 4: Cấu hình phần cứng & Sizing (Capacity Planning)Nhóm 4: Cấu hình phần cứng & Sizing (Capacity Planning)Nhóm 4: Cấu hình phần cứng & Sizing (Capacity Planning)
variable "database_name" {
  type    = string
  default = "ecommerce_db"
}

variable "master_username" {
  type    = string
  default = "dbadmin"
}

variable "aurora_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "aurora_replica_count" {
  type    = number
  default = 2
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.medium"
}

variable "redis_replica_count" {
  type    = number
  default = 2
}

variable "enable_elasticache" {
  type        = bool
  default     = false
  description = "Bật/tắt cụm ElastiCache Redis (tắt khi dùng Floci Emulator do chưa hỗ trợ CreateCacheSubnetGroup)"
}
