variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "cluster_name" {
  type    = string
  default = "cluster-dev"
}

variable "scaling_config" {
  description = "Cấu hình scaling cho node group (desired, min, max)"
  type = object({
    desired_size = number
    min_size     = number
    max_size     = number
  })
}

variable "tags" {
  description = "Tags áp dụng cho tất cả tài nguyên"
  type        = map(string)
  default     = {}
}
