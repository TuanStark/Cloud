resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "order_data" {
  bucket        = "order-data-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "order_data" {
  bucket = aws_s3_bucket.order_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "order_data" {
  bucket = aws_s3_bucket.order_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "order_data" {
  bucket = aws_s3_bucket.order_data.id

  versioning_configuration {
    status = "Enabled"
  }
}
