# KHỐI 1: VPC CỐT LÕI & INTERNET GATEWAY
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
  }
}

# KHỐI 2: 9 SUBNETS TRÊN 3 AVAILABILITY ZONES (3 TẦNG ĐỘC LẬP)
# 1. TẦNG PUBLIC (Chứa ALB & NAT Gateways)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                                            = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
    Tier                                            = "public"
    "kubernetes.io/role/elb"                        = "1" # AWS ALB Controller tìm tag này để đặt Public Load Balancer
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# 2. TẦNG PRIVATE APP (Chứa EKS Worker Nodes & Pods)
resource "aws_subnet" "private_app" {
  count                   = length(var.private_app_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_app_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name                                            = "${var.project_name}-${var.environment}-private-app-${var.availability_zones[count.index]}"
    Tier                                            = "private-app"
    "kubernetes.io/role/internal-elb"               = "1" # Dành cho Internal Load Balancer nội bộ
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "karpenter.sh/discovery"                        = var.eks_cluster_name # Karpenter tìm tag này để tự động bật tắt EC2 Node
  }
}

# 3. TẦNG ISOLATED DATABASE (Chứa Aurora, Redis, MSK - CẤM INTERNET)
resource "aws_subnet" "isolated_db" {
  count                   = length(var.isolated_db_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.isolated_db_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project_name}-${var.environment}-isolated-db-${var.availability_zones[count.index]}"
    Tier = "isolated-database"
  }
}

# KHỐI 3: ELASTIC IPS & NAT GATEWAYS (MULTI-AZ HIGH AVAILABILITY)
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.single_nat_gateway ? 1 : length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "${var.project_name}-${var.environment}-nat-gw-${var.availability_zones[count.index]}"
  }
  depends_on = [aws_internet_gateway.igw]
}

# KHỐI 4: BẢNG ĐIỀU HƯỚNG MẠNG (ROUTE TABLES & ASSOCIATIONS)
# Route Table Public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# 3 Route Tables Riêng Biệt Cho 3 Private Subnets
resource "aws_route_table" "private_app" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[var.single_nat_gateway ? 0 : count.index].id
  }
  tags = { Name = "${var.project_name}-${var.environment}-private-app-rt-${var.availability_zones[count.index]}" }
}

resource "aws_route_table_association" "private_app" {
  count          = length(var.private_app_subnet_cidrs)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# Route Table Isolated Database (Cấm Egress ra Internet)
resource "aws_route_table" "isolated_db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-${var.environment}-isolated-db-rt" }
}

resource "aws_route_table_association" "isolated_db" {
  count          = length(var.isolated_db_subnet_cidrs)
  subnet_id      = aws_subnet.isolated_db[count.index].id
  route_table_id = aws_route_table.isolated_db.id
}

# KHỐI 5: VŨ KHÍ BẢO MẬT & TIẾT KIỆM (S3 GATEWAY ENDPOINT & SUBNET GROUPS)

data "aws_region" "current" {}

# AWS S3 Gateway Endpoint (Hoàn toàn miễn phí, bypass NAT Gateway)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private_app[*].id,
    [aws_route_table.isolated_db.id]
  )
  tags = { Name = "${var.project_name}-${var.environment}-s3-endpoint" }
}

# Subnet Groups gom 3 Isolated Subnets sẵn sàng cho Aurora & Redis
resource "aws_db_subnet_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-subnet-group"
  description = "Subnet group dành riêng cho cụm Amazon Aurora PostgreSQL Multi-AZ"
  subnet_ids  = aws_subnet.isolated_db[*].id
  tags        = { Name = "${var.project_name}-${var.environment}-aurora-subnet-group" }
}

resource "aws_elasticache_subnet_group" "redis" {
  count       = var.enable_elasticache ? 1 : 0
  name        = "${var.project_name}-${var.environment}-redis-subnet-group"
  description = "Subnet group dành riêng cho cụm Amazon ElastiCache Redis Multi-AZ"
  subnet_ids  = aws_subnet.isolated_db[*].id
  tags        = { Name = "${var.project_name}-${var.environment}-redis-subnet-group" }
}
