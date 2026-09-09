resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "invoices" {
  bucket        = "company-invoices-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "company-invoices-${var.environment}"
    Environment = var.environment
    Service     = "OrderProcessing"
  }
}

# 1. Khóa cứng 100% Public Access (CIS AWS Benchmark)
resource "aws_s3_bucket_public_access_block" "invoices" {
  bucket                  = aws_s3_bucket.invoices.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Mã hóa Server-side bằng AES256
resource "aws_s3_bucket_server_side_encryption_configuration" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# 3. Bật Versioning bảo vệ chống xóa nhầm hóa đơn
resource "aws_s3_bucket_versioning" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 4. Tối ưu hóa chi phí lưu trữ tự động (FinOps Lifecycle)
resource "aws_s3_bucket_lifecycle_configuration" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  rule {
    id     = "archive-old-invoices"
    status = "Enabled"
    filter {
      prefix = "invoices/"
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}
