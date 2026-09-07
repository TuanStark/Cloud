output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint # Sẽ được định nghĩa trong module EKS sau
}

output "node_group_arn" {
  value = module.eks.node_group_arn # Tương tự
}
