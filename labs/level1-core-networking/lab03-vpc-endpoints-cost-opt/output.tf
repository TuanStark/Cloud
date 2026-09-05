output "vpc_id" {
  description = "ID của VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs của private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs của public subnets"
  value       = aws_subnet.public[*].id
}

output "s3_gateway_endpoint_id" {
  description = "ID của S3 Gateway Endpoint"
  value       = aws_vpc_endpoint.s3_gateway.id
}

output "interface_endpoint_ids" {
  description = "ID của các Interface Endpoint"
  value = {
    for k, ep in aws_vpc_endpoint.interface : k => ep.id
  }
}

output "nat_gateway_ids" {
  description = "ID của NAT Gateway (nếu có)"
  value       = aws_nat_gateway.main[*].id
}
