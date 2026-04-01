terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    bucket = "pos-pipeline-tf-state"
    key    = "pre-build/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
