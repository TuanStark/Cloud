# ==============================================================================
# LAB 01: AWS ENTERPRISE 3-TIER VPC ARCHITECTURE
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. VIRTUAL PRIVATE CLOUD (VPC)
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "enterprise-cloud-vpc"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------------------------
# 2. INTERNET GATEWAY (IGW) - Cho phép Public Traffic 2 chiều
# ------------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "enterprise-cloud-igw"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------------------------
# 3. TIER 1: PUBLIC SUBNETS (ALB, NAT Gateway, Bastion)
# ------------------------------------------------------------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name        = "enterprise-cloud-public-subnet-a"
    Environment = "dev"
    Tier        = "Public"
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = var.az_b
  map_public_ip_on_launch = true

  tags = {
    Name        = "enterprise-cloud-public-subnet-b"
    Environment = "dev"
    Tier        = "Public"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------------------------
# 4. TIER 2: PRIVATE APP SUBNETS (Backend Services, EKS Nodes)
# ------------------------------------------------------------------------------
resource "aws_subnet" "private_app_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_app_subnet_a_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = false

  tags = {
    Name        = "enterprise-cloud-private-app-subnet-a"
    Environment = "dev"
    Tier        = "Private-App"
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "private_app_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_app_subnet_b_cidr
  availability_zone       = var.az_b
  map_public_ip_on_launch = false

  tags = {
    Name        = "enterprise-cloud-private-app-subnet-b"
    Environment = "dev"
    Tier        = "Private-App"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------------------------
# 5. TIER 3: ISOLATED DATABASE SUBNETS (RDS, ElastiCache)
# ------------------------------------------------------------------------------
resource "aws_subnet" "database_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.database_subnet_a_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = false

  tags = {
    Name        = "enterprise-cloud-database-subnet-a"
    Environment = "dev"
    Tier        = "Isolated-Database"
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "database_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.database_subnet_b_cidr
  availability_zone       = var.az_b
  map_public_ip_on_launch = false

  tags = {
    Name        = "enterprise-cloud-database-subnet-b"
    Environment = "dev"
    Tier        = "Isolated-Database"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------------------------
# 6. NAT GATEWAY & ELASTIC IP (Đặt ở Public Subnet AZ-A)
# ------------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "enterprise-cloud-nat-eip"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name        = "enterprise-cloud-nat-gw"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# 7. ROUTING TABLES & ASSOCIATIONS
# ------------------------------------------------------------------------------

# --- Public Route Table (Trỏ 0.0.0.0/0 -> Internet Gateway) ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "enterprise-cloud-public-rt"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# --- Private App Route Table (Trỏ 0.0.0.0/0 -> NAT Gateway) ---
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "enterprise-cloud-private-app-rt"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private_app.id
}

# --- Database Route Table (ISOLATED - Không có route 0.0.0.0/0 ra ngoài) ---
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "enterprise-cloud-database-rt"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "database_a" {
  subnet_id      = aws_subnet.database_a.id
  route_table_id = aws_route_table.database.id
}

resource "aws_route_table_association" "database_b" {
  subnet_id      = aws_subnet.database_b.id
  route_table_id = aws_route_table.database.id
}