variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "COLUMN_CONFIG" {
  description = "configurations for segregating columns"
  type        = map(map(list(string)))
  default = {
    "buc-ees" = {
      "Trans_date" = ["Week Label"]
      "Store"      = ["Store"]
      "Product"    = ["Item"]
      "EQ Units"   = ["Sale"]
    },
    "qt" = {
      "Trans_date"  = ["Trans Date"]
      "Store no"    = ["Store No"]
      "Address"     = ["Address"]
      "City"        = ["City"]
      "County"      = ["County"]
      "State"       = ["State"]
      "Postal Code" = ["Postal Code"]
      "Product"     = ["Item Description"]
      "Sales"       = ["Total Sales Dollars"]
    }
  }
}

variable "RAW_BUCKET_EMAIL" {
  description = "S3 Bucket to save raw data"
  type        = string
  default     = "pos-raw-email-bucket"
}
variable "TRANSFORMED_BUCKET" {
  description = "S3 Bucket to save transformed data"
  type        = string
  default     = "pos-processed-email-bucket"
}

variable "VENDOR_CONFIG" {
  description = "Vendor identification config — keywords and file filters per vendor"
  type        = map(map(list(string)))
  default = {
    "qt" = {
      "keywords"    = ["qt", "quiktrip"]
      "file_filter" = ["pos"]
    },
    "buc-ees" = {
      "keywords"       = ["buc", "buc-ees", "bucees"]
      "subject_filter" = ["sesh weekly report"]
      "file_filter"    = ["sesh weekly report"]
    },
    "nielsen" = {
      "keywords"    = ["nielsen", "niq", "rms"]
      "file_filter" = ["pos"]
    }
  }
}

variable "project" {
  description = "Project name applied as a tag to all resources"
  type        = string
  default     = "aws-terra"
}

# =============================================================================
# Lambda Layers
# =============================================================================

variable "lambda_layers" {
  description = <<-EOT
    Map of Lambda layer configurations. Each key is a logical name.
    The output ARN can be referenced in lambda_functions[*].layer_arns.
  EOT
  type = map(object({
    layer_name               = string
    filename                 = string
    description              = optional(string, "")
    license_info             = optional(string, null)
    compatible_runtimes      = optional(list(string), [])
    compatible_architectures = optional(list(string), ["x86_64"])
    skip_destroy             = optional(bool, false)
  }))
  default = {}
}

# =============================================================================
# Secrets Manager
# =============================================================================

variable "secrets" {
  description = <<-EOT
    Map of Secrets Manager secrets to create. Each key is a logical name.
    secret_string is sensitive — pass via tfvars or environment variable, never hardcode.
  EOT
  type = map(object({
    secret_name             = string
    description             = optional(string, "")
    kms_key_id              = optional(string, null)
    secret_string           = optional(string, null)
    recovery_window_in_days = optional(number, 30)
    secret_policy           = optional(string, null)
    rotation_lambda_arn     = optional(string, null)
    rotation_days           = optional(number, 30)
  }))
  default = {}
}

# =============================================================================
# S3
# =============================================================================

variable "s3_buckets" {
  description = <<-EOT
    Map of S3 bucket configurations. Each key is a logical name; bucket_name
    must be globally unique. All fields except bucket_name are optional.
  EOT
  type = map(object({
    bucket_name                      = string
    force_destroy                    = optional(bool, false)
    versioning_status                = optional(string, "Disabled")
    sse_algorithm                    = optional(string, "AES256")
    kms_master_key_id                = optional(string, null)
    bucket_key_enabled               = optional(bool, false)
    block_public_acls                = optional(bool, true)
    block_public_policy              = optional(bool, true)
    ignore_public_acls               = optional(bool, true)
    restrict_public_buckets          = optional(bool, true)
    lifecycle_rules                  = optional(list(any), [])
    intelligent_tiering_configurations = optional(list(any), [])
  }))
  default = {}
}

# =============================================================================
# Lambda
# =============================================================================

variable "lambda_functions" {
  description = <<-EOT
    Map of Lambda function configurations. Each key is a logical name that becomes
    part of the function name (my-python-lambda-<key>-<environment>).
    All fields are optional and fall back to the stated defaults.
  EOT
  type = map(object({
    runtime                        = optional(string, "python3.12")
    handler                        = optional(string, "index.handler")
    source_file                    = optional(string, "./src/index.py")
    memory_size                    = optional(number, 256)
    timeout                        = optional(number, 60)
    ephemeral_storage_size         = optional(number, null)
    reserved_concurrent_executions = optional(number, -1)
    architectures                  = optional(list(string), ["arm64"])
    publish                        = optional(bool, true)
    create_alias                   = optional(bool, false)
    log_retention_days             = optional(number, 14)
    log_level                      = optional(string, "INFO")
    layer_arns                     = optional(list(string), [])
  }))
  default = {
    api = {
      memory_size = 256
      timeout     = 60
      log_level   = "INFO"
    }
  }
}
