# ==============================================================
# KHỐI 1: BỘ QUY TẮC PHÒNG THỦ AWS WAF v2 WEB ACL (3 LỚP BẢO VỆ)
# ==============================================================

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-${var.environment}-waf"
  description = "AWS WAF v2 L7 Firewall with Rate-limiting, CRS, and SQLi protection"
  scope       = "REGIONAL" # Dành cho Application Load Balancer

  default_action {
    allow {} # Mặc định cho phép nếu không vi phạm luật
  }

  # ----------------------------------------------------------------------------
  # LUẬT 1: RATE LIMITING (CHỐNG DDOS, BRUTE-FORCE, SPAM ĐẶT HÀNG)
  # Mỗi IP chỉ được gửi tối đa 500 req / 5 phút. Vượt quá sẽ bị CHẶN NGAY LẬP TỨC!
  # ----------------------------------------------------------------------------
  rule {
    name     = "RateLimitPerIP"
    priority = 1

    action {
      block {
        custom_response {
          response_code = 429 # Trả về chuẩn HTTP 429: Too Many Requests
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIPMetric"
      sampled_requests_enabled   = true
    }
  }

  # ----------------------------------------------------------------------------
  # LUẬT 2: AWS MANAGED COMMON RULE SET (CHỐNG OWASP TOP 10)
  # ----------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonMetric"
      sampled_requests_enabled   = true
    }
  }

  # ----------------------------------------------------------------------------
  # LUẬT 3: AWS MANAGED SQL INJECTION RULE SET (CHỐNG TẤN CÔNG DATABASE)
  # ----------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf-overall"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-waf"
  }
}

# ======================================================
# KHỐI 2: APPLICATION LOAD BALANCER (MULTI-AZ MẶT TIỀN)
# ======================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # TIÊU CHUẨN BẢO MẬT: BẬT DROP INVALID HEADERS ĐỂ CHẶN HTTP SMUGGLING
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# ===================================================================
# KHỐI 3: TARGET GROUP & HTTP LISTENER (CHUẨN EKS DIRECT POD ROUTING)
# ===================================================================

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # TIÊU CHUẨN SENIOR: ALB bắn thẳng vào IP của Pod (AWS VPC CNI), không đi qua NodePort!

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}


# ===================================================================
# KHỐI 4: GẮN KHIÊN WAF VÀO TRƯỚC LOAD BALANCER (ASSOCIATION)
# ===================================================================
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
