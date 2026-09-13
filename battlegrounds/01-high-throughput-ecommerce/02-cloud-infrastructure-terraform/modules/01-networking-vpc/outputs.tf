output "vpc_id" {
  description = "ID của VPC vừa khởi tạo"
  value       = aws_vpc.main.id
}

output "environment" {
  description = "Environment"
  value       = var.environment
}

output "vpc_cidr" {
  description = "CIDR block của VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Danh sách ID của 3 Public Subnets"
  value       = aws_subnet.public[*].id
}

output "isolated_db_subnet_ids" {
  description = "Danh sách ID của 3 Isolated DB Subnets"
  value       = aws_subnet.isolated_db[*].id
}

output "private_app_subnet_ids" {
  description = "Danh sách ID của 3 Private App Subnets"
  value       = aws_subnet.private_app[*].id
}

output "nat_gateway_ips" {
  description = "Danh sách IP tĩnh (Elastic IPs) của các NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "aurora_subnet_group_name" {
  description = "Tên DB Subnet Group đã tạo sẵn cho Aurora PostgreSQL"
  value       = aws_db_subnet_group.aurora.name
}

output "redis_subnet_group_name" {
  description = "Tên ElastiCache Subnet Group đã tạo sẵn cho Redis"
  value       = aws_elasticache_subnet_group.redis.name
}
