output "dev_app_bucket_name" {
  description = "Tên bucket được quản lý qua Remote State"
  value       = aws_s3_bucket.app_storage.bucket
}
