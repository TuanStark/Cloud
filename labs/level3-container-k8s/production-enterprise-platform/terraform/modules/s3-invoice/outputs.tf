output "bucket_name" {
  description = "Tên S3 Bucket lưu hóa đơn"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN của S3 Bucket"
  value       = aws_s3_bucket.this.arn
}
