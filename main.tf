provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "darey-s3"
    key = "terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    dynamodb_table = "darey-locks"

  }
}

module "vpc" {
  source = "./modules/vpc"
}

module "s3_bucket" {
  source = "./modules/s3"
}