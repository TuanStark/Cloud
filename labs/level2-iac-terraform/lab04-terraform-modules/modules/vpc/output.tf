# ------------------------------------------------------------------------------
# OUTPUT: VPC CORE
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "ID của VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block của VPC"
  value       = aws_vpc.main.cidr_block
}

# ------------------------------------------------------------------------------
# OUTPUT: SUBNET IDs
# ------------------------------------------------------------------------------
output "public_subnet_ids" {
  description = "Danh sách ID các Public Subnet (dùng cho ALB, NAT Gateway, Bastion)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Danh sách ID các Private Subnet (dùng cho EKS Worker Nodes, Pods, Lambda, RDS)"
  value       = aws_subnet.private[*].id
}

# ------------------------------------------------------------------------------
# OUTPUT: ROUTING & GATEWAYS
# ------------------------------------------------------------------------------
output "public_route_table_id" {
  description = "ID của Public Route Table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Danh sách ID các Private Route Table (mỗi AZ một bảng)"
  value       = aws_route_table.private[*].id
}

output "nat_gateway_public_ips" {
  description = "Danh sách Elastic IPs của các NAT Gateway (dùng để whitelist cho đối tác bên thứ ba)"
  value       = aws_eip.nat[*].public_ip
}

# ------------------------------------------------------------------------------
# OUTPUT: ENDPOINTS (xử lý an toàn khi endpoint bị tắt)
# ------------------------------------------------------------------------------
output "s3_endpoint_id" {
  description = "ID của S3 Gateway Endpoint (nếu có), nếu không tạo thì trả về null"
  value       = try(aws_vpc_endpoint.s3_gateway[0].id, null)
}

output "s3_endpoint_enabled" {
  description = "Trạng thái bật/tắt của S3 Gateway Endpoint"
  value       = var.enable_s3_endpoint
}

# ------------------------------------------------------------------------------
# OUTPUT: BỔ SUNG (tiện ích cho các module khác)
# ------------------------------------------------------------------------------
output "availability_zones_used" {
  description = "Danh sách các Availability Zone đã sử dụng trong VPC"
  value       = var.availability_zones
}

output "nat_gateway_count" {
  description = "Số lượng NAT Gateway đã tạo"
  value       = local.nat_gateway_count
}

output "s3_endpoint_policy" {
  description = "Policy đang áp dụng cho S3 Gateway Endpoint (nếu có)"
  value       = try(aws_vpc_endpoint.s3_gateway[0].policy, null)
}
