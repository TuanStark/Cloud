# KHỐI 1: KHÓA MÃ HÓA KMS CMK & ALIAS

# 1. Customer Managed Key (CMK)
resource "aws_kms_key" "main" {
  description             = "KMS CMK for ${var.project_name}-${var.environment} Data Encryption at Rest"
  deletion_window_in_days = 30
  enable_key_rotation     = true # Bắt buộc bật: Tự động xoay khóa sau mỗi 365 ngày (PCI-DSS & SOC2)
  tags = {
    Name        = "${var.project_name}-${var.environment}-kms"
    Environment = var.environment
  }
}


# 2. KMS Alias (Bí danh dễ nhớ)
resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}-key"
  target_key_id = aws_kms_key.main.key_id
}

# KHỐI 2: SECURITY GROUP CHO APPLICATION LOAD BALANCER (TẦNG BIÊN)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security Group cho Public Application Load Balancer"
  vpc_id      = var.vpc_id

  # Mở Port 80 (HTTP) đón khách
  ingress {
    description = "Allow HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Mở Port 443 (HTTPS) đón khách
  ingress {
    description = "Allow HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Cho phép ALB chuyển tiếp traffic đến các Pods trong EKS
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

# KHỐI 3: SECURITY GROUP CHO EKS NODES (TẦNG TÍNH TOÁN)
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-${var.environment}-eks-nodes-sg"
  description = "Security Group cho EKS Worker Nodes & Pods"
  vpc_id      = var.vpc_id

  # MẮT XÍCH 1: CHỈ cho phép traffic có nguồn gốc từ Security Group của ALB!
  ingress {
    description     = "Allow traffic from ALB only"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # <-- CHAINING TỪ ALB!
  }

  # Cho phép các Pods trong cụm EKS nói chuyện nội bộ với nhau (CoreDNS, Calico/Cilium)
  ingress {
    description = "Allow node-to-node internal communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Egress: Đi ra ngoài Internet qua NAT Gateway để kéo image, gọi 3rd party API
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-nodes-sg"
  }
}

# KHỐI 4: 3 SECURITY GROUPS CHO TẦNG DỮ LIỆU & HÀNG ĐỢI (AURORA, REDIS, MSK)
# 1. Security Group cho Amazon Aurora PostgreSQL (Port 5432)
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-sg"
  description = "Security Group cho Aurora PostgreSQL Multi-AZ"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow PostgreSQL from EKS Nodes only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id] # <-- CHỈ TIN TƯỞNG EKS NODES!
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-sg"
  }
}

# 2. Security Group cho Amazon ElastiCache Redis (Port 6379)
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Security Group cho ElastiCache Redis Cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Redis from EKS Nodes only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id] # <-- CHỈ TIN TƯỞNG EKS NODES!
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-sg"
  }
}

# 3. Security Group cho Amazon MSK Kafka (Port 9092 & 9094)
resource "aws_security_group" "msk" {
  name        = "${var.project_name}-${var.environment}-msk-sg"
  description = "Security Group cho Amazon MSK (Apache Kafka) Cluster"
  vpc_id      = var.vpc_id

  # Port 9092: Plaintext / Port 9094: TLS Encryption
  ingress {
    description     = "Allow Kafka PLAINTEXT from EKS Nodes only"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    description     = "Allow Kafka TLS from EKS Nodes only"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-msk-sg"
  }
}
