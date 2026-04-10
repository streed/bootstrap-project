terraform {
  required_version = ">= 1.5"

  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "~> 0.6"
    }
  }

  # Uncomment to use remote state (recommended for teams)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "railway/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "railway" {
  token = var.railway_api_token
}
