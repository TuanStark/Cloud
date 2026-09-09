output "s3_bucket_name" {
  description = "Tên S3 Bucket lưu hóa đơn môi trường Dev"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN của S3 Bucket môi trường Dev"
  value       = module.s3.bucket_arn
}

output "irsa_role_arn" {
  description = "ARN của IAM Role để gắn vào ServiceAccount Dev"
  value       = module.irsa.role_arn
}
