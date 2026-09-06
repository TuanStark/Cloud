# ----- VPC Core -----
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID của VPC"
}

output "vpc_cidr_block" {
  value       = module.vpc.vpc_cidr_block
  description = "CIDR block của VPC"
}

# ----- Subnet IDs -----
output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "Danh sách ID các Public Subnet"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "Danh sách ID các Private Subnet"
}

# ----- Routing & Gateways -----
output "public_route_table_id" {
  value       = module.vpc.public_route_table_id
  description = "ID của Public Route Table"
}

output "private_route_table_ids" {
  value       = module.vpc.private_route_table_ids
  description = "Danh sách ID các Private Route Table (mỗi AZ một bảng)"
}

output "nat_gateway_public_ips" {
  value       = module.vpc.nat_gateway_public_ips
  description = "Danh sách Elastic IP của NAT Gateway (dùng để whitelist đối tác)"
}

# ----- Endpoints -----
output "s3_endpoint_id" {
  value       = module.vpc.s3_endpoint_id
  description = "ID của S3 Gateway Endpoint (null nếu không bật)"
}
