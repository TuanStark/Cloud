resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.main.id
  
  # ---------- INBOUND ----------
  # Rule 50: DENY hacker IP (203.0.113.50/32) – được xét trước
  ingress {
    rule_no    = 50
    action     = "deny"
    protocol   = "tcp"
    cidr_block = "203.0.113.50/32"
    from_port  = 0
    to_port    = 65535          # Chặn tất cả TCP từ IP này
  }

  # Rule 100: ALLOW HTTP từ internet
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Rule 110: ALLOW HTTPS từ internet
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # ---------- OUTBOUND ----------
  # Rule 100: ALLOW ephemeral ports (1024-65535) để trả lời client
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # (Các rule khác không được định nghĩa sẽ bị DENY mặc định)

  tags = { Name = "public-nacl" }
}

# Gán NACL vào Public Subnet
resource "aws_network_acl_association" "public" {
  subnet_id      = aws_subnet.public.id
  network_acl_id = aws_network_acl.public_nacl.id
}