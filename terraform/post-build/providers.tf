terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    bucket = "pos-pipleine-tf-state"
    key    = "post-build/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 1.0"
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

data "aws_secretsmanager_secret_version" "snowflake_creds" {
  secret_id = "snowflake/pos-pipeline/${var.environment}/credentials"
}

data "aws_secretsmanager_secret_version" "snowflake_key" {
  secret_id = "snowflake/pos-pipeline/${var.environment}/private-key"
}

locals {
  snowflake_creds = jsondecode(
    data.aws_secretsmanager_secret_version.snowflake_creds.secret_string
  )
}

provider "snowflake" {
  organization_name = local.snowflake_creds["organization"]
  account_name      = local.snowflake_creds["account"]
  user              = local.snowflake_creds["username"]
  private_key       = data.aws_secretsmanager_secret_version.snowflake_key.secret_string
  authenticator     = "SNOWFLAKE_JWT"
  role              = "ACCOUNTADMIN"
  warehouse         = "COMPUTE_WH"

  preview_features_enabled = [
    "snowflake_file_format_resource",
    "snowflake_storage_integration_resource",
    "snowflake_stage_resource",
    "snowflake_pipe_resource"
  ]
}