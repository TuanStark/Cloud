terraform {
  backend "s3" {
    bucket                      = "tuanstark-tfstate-f8m8ns"
    key                         = "dev/terraform.tfstate"
    region                      = "ap-southeast-1"
    dynamodb_table              = "tuanstark-tfstate-locks"
    encrypt                     = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true

    endpoints = {
      s3       = "https://chungkhoanai.dpdns.org"
      dynamodb = "https://chungkhoanai.dpdns.org"
    }
  }
}
