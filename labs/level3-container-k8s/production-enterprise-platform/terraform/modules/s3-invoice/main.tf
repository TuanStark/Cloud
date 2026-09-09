resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "this" {
  bucket        = "company-invoices-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = var.force_destroy

  tags = {
    Name        = "company-invoices-${var.environment}"
    Environment = var.environment
    Service     = "OrderProcessing"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Chỉ kích hoạt Lifecycle khi enable_lifecycle_archive = true (Dành cho Prod)
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle_archive ? 1 : 0
  bucket = aws_s3_bucket.this.id

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
