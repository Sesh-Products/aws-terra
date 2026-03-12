# =============================================================================
# Lambda Layers
# =============================================================================
module "pandas_layer" {
  source = "./modules/compute/layer"

  use_ssm_layer  = true
  pandas_version = "3.15.1"
  python_version = "py3.12"
  architecture   = "arm64"
}

module "layer" {
  for_each = var.lambda_layers
  source   = "./modules/compute/layer"

  layer_name               = each.value.layer_name
  filename                 = each.value.filename
  source_code_hash         = filebase64sha256(each.value.filename)
  description              = each.value.description
  license_info             = each.value.license_info
  compatible_runtimes      = each.value.compatible_runtimes
  compatible_architectures = each.value.compatible_architectures
  skip_destroy             = each.value.skip_destroy
}

# =============================================================================
# Secrets Manager
# =============================================================================

module "secrets" {
  for_each = var.secrets
  source   = "./modules/secrets"

  secret_name             = each.value.secret_name
  description             = each.value.description
  kms_key_id              = each.value.kms_key_id
  secret_string           = each.value.secret_string
  recovery_window_in_days = each.value.recovery_window_in_days
  secret_policy           = each.value.secret_policy
  rotation_lambda_arn     = each.value.rotation_lambda_arn
  rotation_days           = each.value.rotation_days

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# =============================================================================
# S3 Buckets
# =============================================================================

module "storage" {
  for_each = var.s3_buckets
  source   = "./modules/storage"

  bucket_name                        = each.value.bucket_name
  force_destroy                      = each.value.force_destroy
  versioning_status                  = each.value.versioning_status
  sse_algorithm                      = each.value.sse_algorithm
  kms_master_key_id                  = each.value.kms_master_key_id
  bucket_key_enabled                 = each.value.bucket_key_enabled
  block_public_acls                  = each.value.block_public_acls
  block_public_policy                = each.value.block_public_policy
  ignore_public_acls                 = each.value.ignore_public_acls
  restrict_public_buckets            = each.value.restrict_public_buckets
  lifecycle_rules                    = each.value.lifecycle_rules
  intelligent_tiering_configurations = each.value.intelligent_tiering_configurations
  seed_files                         = each.value.seed_files

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# =============================================================================
# Lambda
# =============================================================================

data "archive_file" "lambda_zips" {
  for_each = var.lambda_functions

  type        = "zip"
  source_dir = "${path.root}/src/${each.key}"
  output_path = "${path.root}/.builds/${each.key}.zip"
}

module "compute" {
  for_each = var.lambda_functions
  source   = "./modules/compute"

  function_name = "${each.key}-${var.environment}"
  description   = "Python Lambda function - ${each.key} - ${var.environment} environment"
  runtime       = each.value.runtime
  handler       = each.value.handler
  
  layer_arns = concat(
  [module.pandas_layer.layer_arn],
  coalesce(each.value.layer_arns, [])
  )
  s3_bucket_arns = [
    "arn:aws:s3:::pos-raw-email-bucket",     
    "arn:aws:s3:::pos-processed-email-bucket",
    "arn:aws:s3:::pos-lookup-data",
    "arn:aws:s3:::product-upc-mapping"
  ]
  filename         = data.archive_file.lambda_zips[each.key].output_path
  source_code_hash = data.archive_file.lambda_zips[each.key].output_base64sha256

  memory_size                    = each.value.memory_size
  timeout                        = each.value.timeout
  ephemeral_storage_size         = each.value.ephemeral_storage_size
  reserved_concurrent_executions = each.value.reserved_concurrent_executions
  architectures                  = each.value.architectures

  publish      = each.value.publish
  create_alias = each.value.create_alias



  cloudwatch_log_group_retention_days = each.value.log_retention_days

  environment_variables = {
    ENVIRONMENT = var.environment
    LOG_LEVEL   = each.value.log_level
    COLUMN_CONFIG = jsonencode(var.COLUMN_CONFIG)
    VENDOR_CONFIG = jsonencode(var.VENDOR_CONFIG)
    RAW_BUCKET_EMAIL = var.RAW_BUCKET_EMAIL
    TRANSFORMED_BUCKET = var.TRANSFORMED_BUCKET

  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

