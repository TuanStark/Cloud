region       = "us-east-1"
environment  = "dev"
cluster_name = "cluster-dev"

scaling_config = {
  desired_size = 2
  min_size     = 1
  max_size     = 3
}

tags = {
  Environment = "dev"
  Project     = "lab08-eks"
  ManagedBy   = "Terraform"
}
