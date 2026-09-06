resource "aws_s3_bucket" "app_storage" {
  bucket = "tuanstark-dev-app-storage"

  tags = {
    Environment = "dev"
    Project     = "lab05-state-management"
    ManagedBy   = "terraform"
  }
}

