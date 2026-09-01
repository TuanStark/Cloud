resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "enterprise-cloud-vpc"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "enterprise-cloud-internet-gateway"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_a_cidr
  availability_zone = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name        = "enterprise-cloud-public-subnet-a"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_b_cidr
  availability_zone = var.az_b
  map_public_ip_on_launch = true

  tags = {
    Name        = "enterprise-cloud-public-subnet-b"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "enterprise-cloud-public-route-table"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public.id
}
# =========================================
#  PHẦN MỚI: NAT, PRIVATE APP SUBNETS, DB SUBNETS
# =========================================

resource "aws_subnet" "private_subnet_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_a_cidr
  availability_zone = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name        = "enterprise-cloud-private-subnet-a"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_b_cidr
  availability_zone = var.az_b
  map_public_ip_on_launch = true

  tags = {
    Name        = "enterprise-cloud-private-subnet-b"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_subnet" "private_subnet_database" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_database_cidr
  availability_zone = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name        = "enterprise-cloud-private-subnet-database"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_subnet" "private_subnet_database_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_database_b_cidr
  availability_zone = var.az_b
  map_public_ip_on_launch = true

  tags = {
    Name        = "enterprise-cloud-private-subnet-database-b"
    environment = "dev"
    managedby   = "terraform"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name = "main-nat-gw"
  }

  # Đảm bảo NAT gateway chỉ được tạo sau khi IGW và EIP sẵn sàng (không bắt buộc nhưng an toàn)
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "enterprise-cloud-private-route-table"
    environment = "dev"
    managedby   = "terraform"
  }
}

# ---- Gán Private Route Table vào 2 Private App Subnets ----
resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private_app.id
}

# ---- Gán Private Route Table vào 2 Private DB Subnets ----
resource "aws_route_table_association" "private_db_a" {
  subnet_id      = aws_subnet.private_db_a.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_route_table_association" "private_db_b" {
  subnet_id      = aws_subnet.private_db_b.id
  route_table_id = aws_route_table.private_db.id
}