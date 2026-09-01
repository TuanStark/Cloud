output "vpc_id" {
  description = "ID của VPC vừa tạo"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Danh sách ID các Public Subnets"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_app_subnet_ids" {
  description = "Danh sách ID các Private App Subnets"
  value       = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
}

output "database_subnet_ids" {
  description = "Danh sách ID các Isolated Database Subnets"
  value       = [aws_subnet.database_a.id, aws_subnet.database_b.id]
}

output "nat_gateway_public_ip" {
  description = "Public Elastic IP của NAT Gateway"
  value       = aws_eip.nat.public_ip
}
