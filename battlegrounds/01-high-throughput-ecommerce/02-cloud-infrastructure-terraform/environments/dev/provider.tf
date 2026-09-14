terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # ============================================================================
  # ĐIỀU HƯỚNG TOÀN BỘ DỊCH VỤ AWS SANG FLOCI CLOUD EMULATOR
  # ============================================================================
  endpoints {
    ec2         = "https://chungkhoanai.dpdns.org/"
    iam         = "https://chungkhoanai.dpdns.org/"
    kms         = "https://chungkhoanai.dpdns.org/"
    eks         = "https://chungkhoanai.dpdns.org/"
    sts         = "https://chungkhoanai.dpdns.org/"
    s3          = "https://chungkhoanai.dpdns.org/"
    rds         = "https://chungkhoanai.dpdns.org/"
    elasticache = "https://chungkhoanai.dpdns.org/"
    kafka       = "https://chungkhoanai.dpdns.org/"
    elb         = "https://chungkhoanai.dpdns.org/"
    elbv2       = "https://chungkhoanai.dpdns.org/"
    wafv2       = "https://chungkhoanai.dpdns.org/"
    cloudwatch  = "https://chungkhoanai.dpdns.org/"
    logs        = "https://chungkhoanai.dpdns.org/"
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Le Cong Tuan"
      Repository  = "Cloud-Mentorship-Battlegrounds"
    }
  }
}
