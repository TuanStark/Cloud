# .tflint.hcl
# Cấu hình TFLint và kích hoạt Ruleset cho AWS Provider

plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Bật rule kiểm tra phiên bản provider có được pin chặt chẽ không
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

# Kiểm tra naming conventions chuẩn snake_case
rule "terraform_naming_convention" {
  enabled = true
}

# Kiểm tra các biến khai báo nhưng không dùng (Dead code)
rule "terraform_unused_declarations" {
  enabled = true
}
