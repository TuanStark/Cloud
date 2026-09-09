terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region                     = var.region
  access_key                 = "test"
  secret_key                 = "test"
  skip_metadata_api_check    = true
  skip_requesting_account_id = true
  s3_use_path_style          = true

  endpoints {
    ec2 = "https://chungkhoanai.dpdns.org/"
    iam = "https://chungkhoanai.dpdns.org/"
    kms = "https://chungkhoanai.dpdns.org/"
    eks = "https://chungkhoanai.dpdns.org/"
    sts = "https://chungkhoanai.dpdns.org/"
    s3  = "https://chungkhoanai.dpdns.org/"
  }
}
