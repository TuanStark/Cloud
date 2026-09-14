variable "project_name" {
  type    = string
  default = "ecommerce"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "vpc_id" {
  type = string
}

variable "private_app_subnet_ids" {
  type = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "eks_nodes_security_group_id" {
  type = string
}

variable "system_node_instance_types" {
  type    = list(string)
  default = ["t3.medium"] # 1 CPU, 4GB RAM (Dùng cho K8s System DaemonSets)
}

variable "system_node_min_size" {
  type    = number
  default = 2
}

variable "system_node_max_size" {
  type    = number
  default = 4
}

variable "system_node_desired_size" {
  type    = number
  default = 2
}
