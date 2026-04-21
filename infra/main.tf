terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.34.0"
    }
  }

  backend "s3" {
    bucket = "read-for-me-tfstate"
    key = "terraform.tfstate"
    region = "ap-south-1"
  }
} 

provider "aws" {
  region = "ap-south-1"
}
