# ==========================================
## VPC & SUBNET
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-main"
  }
}

# Public subnets (cho NAT Gateway và Bastion nếu có)
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private subnets (cho workloads)
resource "aws_subnet" "private" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}
# ==========================================
## INTERNET GATEWAY & ROUTE TABLES
# ==========================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Gán public route table cho các public subnet
resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table (sẽ được cập nhật với NAT và VPC Endpoint routes)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private-rt"
  }
}

# Gán private route table cho private subnets
resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ==========================================
## NAT GATEWAY
# ==========================================
# Chỉ tạo NAT Gateway nếu biến enable_nat_gateway = true
# Nếu single_nat_gateway = true thì chỉ tạo 1 NAT ở AZ đầu tiên, ngược lại tạo ở mỗi AZ
locals {
  nat_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.az_count) : 0
}

# Elastic IP cho NAT Gateway
resource "aws_eip" "nat" {
  count = local.nat_count
  tags = {
    Name = "nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # nếu single thì dùng AZ 0

  tags = {
    Name = "nat-gw-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Thêm route 0.0.0.0/0 tới NAT Gateway trong private route table
resource "aws_route" "private_nat" {
  count                  = local.nat_count > 0 ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id # nếu chỉ 1 NAT; nếu có nhiều NAT, có thể cần route riêng cho từng subnet, nhưng đơn giản hóa dùng 1 NAT chung
}

# Nếu muốn dùng 1 NAT duy nhất cho tất cả private subnet, route trên là đủ.
# Nếu muốn mỗi AZ có NAT riêng, cần tạo route table riêng cho từng subnet, nhưng trong phạm vi demo này dùng 1 NAT.


# ==========================================
## VPC ENDPOINTS
# ==========================================
# Gateway Endpoint cho S3
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  route_table_ids = [
    aws_route_table.private.id,
    ## update sau khi review
    aws_route_table.public.id # 👈 Thêm dòng này để Bastion/CI runner trong Public Subnet được hưởng lợi
  ]

  policy = data.aws_iam_policy_document.s3_endpoint_policy.json

  tags = {
    Name = "s3-gateway-endpoint"
  }
}

# Gateway Endpoint cho DynamoDB
resource "aws_vpc_endpoint" "dynamodb_gateway" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"

  route_table_ids = [
    aws_route_table.private.id
  ]

  # DynamoDB thường không cần policy phức tạp, nhưng có thể thêm nếu cần
  tags = {
    Name = "dynamodb-gateway-endpoint"
  }
}

# S3 Policy cho phép truy cập bucket
data "aws_iam_policy_document" "s3_endpoint_policy" {
  # Cho phép truy cập vào bucket chỉ định
  statement {
    # update sau khi review
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::${var.allowed_s3_bucket}",
      "arn:aws:s3:::${var.allowed_s3_bucket}/*"
    ]
  }
}

# Interface Endpoint (PrivateLink) cho các dịch vụ khác (CloudWatch, ECR, KMS, Secrets Manager…)
resource "aws_security_group" "vpce" {
  name        = "vpce-sg"
  description = "Allow inbound HTTPS from private subnets"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpce-sg"
  }
}

## Danh sách các Interface Endpoint thường dùng

locals {
  interface_endpoint_services = [
    "com.amazonaws.${data.aws_region.current.name}.logs",           # CloudWatch Logs
    "com.amazonaws.${data.aws_region.current.name}.monitoring",     # CloudWatch Metrics
    "com.amazonaws.${data.aws_region.current.name}.ecr.api",        # ECR API
    "com.amazonaws.${data.aws_region.current.name}.ecr.dkr",        # ECR Docker Registry
    "com.amazonaws.${data.aws_region.current.name}.kms",            # KMS
    "com.amazonaws.${data.aws_region.current.name}.secretsmanager", # Secrets Manager
    # Thêm các service khác nếu cần: "com.amazonaws.region.sqs", "com.amazonaws.region.sns", v.v.
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoint_services)

  vpc_id              = aws_vpc.main.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce.id]

  tags = {
    Name = "vpce-${split(".", each.value)[3]}"
  }
}
