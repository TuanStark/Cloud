output "irsa_role_arn" {
  description = "ARN của IAM Role cấp quyền cho Pod"
  value       = aws_iam_role.order_irsa.arn
}

output "s3_bucket_name" {
  description = "Tên S3 Bucket lưu trữ dữ liệu ứng dụng"
  value       = aws_s3_bucket.order_data.id
}

output "s3_bucket_arn" {
  description = "ARN của S3 Bucket"
  value       = aws_s3_bucket.order_data.arn
}
