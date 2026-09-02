# ---------- ALB SG ----------
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic (to backend)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "alb-sg"}
}

# ---------- Backend SG ----------
resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Security group for backend instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "NestJS port from ALB SG"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # Nguồn là ALB SG
  }

  ingress {
    description = "SSH from Bastion CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_cidr]                  # Chỉ từ dải Bastion
  }

  egress {
    description = "Allow all outbound (via NAT GW)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "backend-sg" }
}

# ---------- Database SG ----------
resource "aws_security_group" "database_sg" {
  name        = "database-sg"
  description = "Security group for database instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Backend SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id] # Chỉ từ Backend SG
  }

  egress {
    description = "Allow only within VPC (isolated)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]                           # Chỉ trong VPC
  }
  
  tags = { Name = "database-sg" }
}