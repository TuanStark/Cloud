output "s3_bucket_name" {
  description = "Tên S3 Bucket lưu trữ hóa đơn điện tử"
  value       = aws_s3_bucket.invoices.id
}

output "s3_bucket_arn" {
  description = "ARN của S3 Bucket"
  value       = aws_s3_bucket.invoices.arn
}

output "irsa_role_arn" {
  description = "ARN của IAM Role để gắn vào Kubernetes ServiceAccount"
  value       = aws_iam_role.order_backend_irsa.arn
}
