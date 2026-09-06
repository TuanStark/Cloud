output "s3_bucket_name" {
  description = "Tên của S3 bucket dùng để lưu trữ Terraform state"
  value       = aws_s3_bucket.remote_state_bucket.bucket
}


output "dynamodb_table_name" {
  description = "Tên của DynamoDB table dùng để khóa Terraform state"
  value       = aws_dynamodb_table.terraform_state_lock.name
}
