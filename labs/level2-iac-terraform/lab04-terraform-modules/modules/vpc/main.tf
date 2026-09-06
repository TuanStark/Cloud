# Khối VPC & Subnets:
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-subnet-${count.index + 1}"
  })
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-subnet-${count.index + 1}"
  })
}

# Khối Internet Gateway & Public Route:
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-route-table"
  })
}

# Gán tất cả public subnet vào public route table này.
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}


# Khối NAT Gateway & Routing Đa Môi Trường (Logic cốt lõi):
locals {
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # single NAT đặt ở AZ đầu tiên
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gw-${count.index + 1}"
  })
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${var.availability_zones[count.index]}"
  })
}
# Định tuyến 0.0.0.0/0 ra NAT Gateway (Linh hoạt Single NAT vs Multi-AZ NAT)
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? length(var.private_subnet_cidrs) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}


# Khối S3 Gateway Endpoint:
resource "aws_vpc_endpoint" "s3_gateway" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  # Gắn vào tất cả private route tables (mỗi AZ) và cả public route table
  route_table_ids = concat(
    aws_route_table.private[*].id,
    [aws_route_table.public.id]
  )

  # Policy giới hạn truy cập chỉ vào bucket được chỉ định (đã định nghĩa trong data)
  policy = var.enable_s3_endpoint ? data.aws_iam_policy_document.s3_endpoint_policy[0].json : null

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-gateway-endpoint"
  })
}

# ------------------------------------------------------------------------------
# DATA SOURCE: Lấy region hiện tại để tạo service name
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# POLICY DOCUMENT CHO S3 ENDPOINT (chỉ cho phép bucket xác định)
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "s3_endpoint_policy" {
  count = var.enable_s3_endpoint ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::${var.allowed_s3_bucket}",
      "arn:aws:s3:::${var.allowed_s3_bucket}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
  # Không cần Deny – mọi bucket khác tự động bị từ chối do không có Allow
}
