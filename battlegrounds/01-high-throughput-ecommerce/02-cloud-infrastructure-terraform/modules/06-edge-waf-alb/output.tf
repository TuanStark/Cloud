# ==============================================================
# 1. THÔNG SỐ APPLICATION LOAD BALANCER (ALB)
# ==============================================================
output "alb_id" {
  description = "ID của Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN của Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS công khai của ALB (Dùng để test curl trực tiếp hoặc trỏ CNAME)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical Hosted Zone ID của ALB (Dùng để tạo Route 53 Alias Record)"
  value       = aws_lb.main.zone_id
}

# ==============================================================
# 2. TARGET GROUP & LISTENER
# ==============================================================
output "target_group_arn" {
  description = "ARN của Target Group (Dành cho AWS Load Balancer Controller / Pod registration)"
  value       = aws_lb_target_group.app.arn
}

output "http_listener_arn" {
  description = "ARN của HTTP Listener cổng 80"
  value       = aws_lb_listener.http.arn
}

# ==============================================================
# 3. LÁ CHẮN AWS WAF v2
# ==============================================================
output "waf_web_acl_id" {
  description = "ID của AWS WAF v2 Web ACL"
  value       = aws_wafv2_web_acl.main.id
}

output "waf_web_acl_arn" {
  description = "ARN của AWS WAF v2 Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}
