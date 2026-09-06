terraform {
  required_version = ">= 1.5.0" # Thêm dòng này để tận dụng các tính năng mới
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
