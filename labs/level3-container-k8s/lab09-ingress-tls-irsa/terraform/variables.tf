variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment"
  default     = "dev"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "cluster-dev"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace"
  default     = "order-app"
}

variable "service_account_name" {
  type        = string
  description = "Service account name for IAM IRSA"
  default     = "order-app-sa"
}
