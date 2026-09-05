terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Lấy danh sách AZ khả dụng (chỉ lấy số lượng cần)
data "aws_availability_zones" "available" {
  state = "available"
}
