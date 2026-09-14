variable "project_name" {
  type    = string
  default = "ecommerce"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_id" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "waf_rate_limit" {
  type    = number
  default = 500
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs for ALB deployment"
}
