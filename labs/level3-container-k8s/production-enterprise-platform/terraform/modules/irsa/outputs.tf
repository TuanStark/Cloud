output "role_arn" {
  description = "ARN của IAM Role phục vụ cấu hình IRSA cho ServiceAccount"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Tên IAM Role"
  value       = aws_iam_role.this.name
}
