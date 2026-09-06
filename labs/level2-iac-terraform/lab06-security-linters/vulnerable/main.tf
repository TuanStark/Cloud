# ==============================================================================
# HẠ TẦNG MẪU CHỨA CÁC LỖI BẢO MẬT & CÚ PHÁP ĐIỂN HÌNH (VULNERABLE INFRASTRUCTURE)
# ==============================================================================
# Mục đích: Dùng để kiểm tra khả năng phát hiện của TFLint, Checkov và Trivy.
# TUYỆT ĐỐI KHÔNG SỬ DỤNG FILE NÀY CHO MÔI TRƯỜNG PRODUCTION!
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. S3 BUCKET NGUY HIỂM (Không mã hóa, không versioning, không chặn public)
# Vi phạm:
# - CKV_AWS_19 / CKV_AWS_145 / AVD-AWS-0132: S3 bucket thiếu Server-side encryption
# - CKV_AWS_21 / AVD-AWS-0090: S3 bucket thiếu Versioning
# - CKV_AWS_53, 54, 55, 56 / AVD-AWS-0093: Thiếu Public Access Block
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "insecure_data_lake" {
  bucket = "company-sensitive-customer-data-lake-raw"

  tags = {
    Name        = "Insecure Data Lake"
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# 2. SECURITY GROUP NGUY HIỂM (Mở cổng quản trị SSH và Database ra toàn Internet)
# Vi phạm:
# - CKV_AWS_24 / AVD-AWS-0107: Security Group mở port 22 (SSH) ra 0.0.0.0/0
# - CKV_AWS_260 / AVD-AWS-0124: Mở port 5432 (PostgreSQL) ra toàn cầu
# ------------------------------------------------------------------------------
resource "aws_security_group" "database_and_admin_sg" {
  name        = "db-and-admin-sg"
  description = "Security group cho database va admin SSH"
  vpc_id      = "vpc-12345678" # Giả lập VPC ID

  # Cực kỳ nguy hiểm: Mở SSH cho cả thế giới
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Cực kỳ nguy hiểm: Mở cổng Database cho cả thế giới
  ingress {
    description = "PostgreSQL from anywhere"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# 3. EC2 INSTANCE CHỨA LỖ HỔNG (Sai loại instance, thiếu IMDSv2, EBS không mã hoá)
# Vi phạm:
# - TFLint AWS Plugin: "t2.microooo" là instance type không tồn tại trên AWS!
# - CKV_AWS_79 / AVD-AWS-0028: Thiếu cấu hình IMDSv2 (dẫn tới lỗ hổng SSRF Capital One)
# - CKV_AWS_8 / AVD-AWS-0130: Root block device không được mã hóa (encrypted = false)
# - CKV_AWS_88 / AVD-AWS-0053: Gán Public IP trực tiếp cho EC2 trong private workload
# ------------------------------------------------------------------------------
resource "aws_instance" "legacy_web_app" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2
  instance_type = "t2.microooo"           # Lỗi gõ sai instance type! (TFLint sẽ bắt)

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.database_and_admin_sg.id]

  # Root block device không mã hóa
  root_block_device {
    volume_size = 20
    encrypted   = false
  }

  # Không có block metadata_options -> AWS mặc định cho phép IMDSv1 (lỗ hổng SSRF)

  tags = {
    Name        = "Vulnerable Web App"
    Environment = var.environment
  }
}
