variable "project_name" {
  type    = string
  default = "ecommerce"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "subnet_ids" {
  type = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "msk_security_group_id" {
  type = string
}

variable "kafka_version" {
  type    = string
  default = "3.5.1"
}

variable "broker_instance_type" {
  type    = string
  default = "kafka.t3.small"
}

variable "ebs_volume_size" {
  type    = number
  default = 50
}
