locals {
  snowflake_layer_arn = try(module.layer["snowflake_connector"].layer_arn, "")
}

# =============================================================================
# Lambda Layers
# =============================================================================

module "layer" {
  for_each = var.lambda_layers
  source   = "./modules/compute/layer"

  layer_name               = each.value.layer_name
  filename                 = data.archive_file.layer_zips[each.key].output_path        # ← from archive
  source_code_hash         = data.archive_file.layer_zips[each.key].output_base64sha256 # ← from archive
  description              = each.value.description
  license_info             = each.value.license_info
  compatible_runtimes      = each.value.compatible_runtimes
  compatible_architectures = each.value.compatible_architectures
  skip_destroy             = each.value.skip_destroy
}

data "archive_file" "layer_zips" {
  for_each = var.lambda_layers

  type        = "zip"
  source_dir  = each.value.source_dir
  output_path = "${path.root}/.builds/${each.key}-layer.zip"
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

  snowflake_enabled                  = each.value.snowflake_enabled
  snowflake_iam_role_name            = each.value.snowflake_iam_role_name
  snowflake_storage_integration_name = each.value.snowflake_storage_integration_name
  snowflake_database                 = each.value.snowflake_database
  snowflake_schema                   = each.value.snowflake_schema
  snowflake_table                    = each.value.snowflake_table
  snowflake_stage_name               = each.value.snowflake_stage_name
  snowflake_pipe_name                = each.value.snowflake_pipe_name
  snowflake_file_format_name         = each.value.snowflake_file_format_name

  snowflake_stream_name              = each.value.snowflake_stream_name
  snowflake_task_schema              = each.value.snowflake_task_schema
  snowflake_backup_schema            = each.value.snowflake_backup_schema
  snowflake_dim_schema               = each.value.snowflake_dim_schema
  snowflake_fact_schema              = each.value.snowflake_fact_schema
  snowflake_backup_task_name         = each.value.snowflake_backup_task_name
  snowflake_fact_task_name           = each.value.snowflake_fact_task_name
  bucket_policy                      = each.value.bucket_policy
  notification_configuration         = each.value.notification_configuration
  depends_on                         = [module.compute]
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
  source_dir = each.value.source_dir
  output_path = "${path.root}/.builds/${each.key}.zip"
}

module "compute" {
  for_each = var.lambda_functions
  source   = "./modules/compute"

  function_name = coalesce(each.value.function_name, "${each.key}-${var.environment}")
  description   = "Python Lambda function - ${each.key} - ${var.environment} environment"
  runtime       = each.value.runtime
  handler       = each.value.handler
  allowed_triggers = each.value.allowed_triggers
  filename         = data.archive_file.lambda_zips[each.key].output_path
  source_code_hash = data.archive_file.lambda_zips[each.key].output_base64sha256

  memory_size                    = each.value.memory_size
  timeout                        = each.value.timeout
  ephemeral_storage_size         = each.value.ephemeral_storage_size
  reserved_concurrent_executions = each.value.reserved_concurrent_executions
  architectures                  = each.value.architectures

  publish      = each.value.publish
  create_alias = each.value.create_alias

  layer_arns = each.key == "pos_transform" && local.snowflake_layer_arn != "" ? concat(each.value.layer_arns, [local.snowflake_layer_arn]) : each.value.layer_arns
  additional_policy_statements = each.value.additional_policy_statements
  cloudwatch_log_group_retention_days = each.value.log_retention_days
  environment_variables = merge(
  {
    ENVIRONMENT = var.environment
    LOG_LEVEL   = each.value.log_level
  },
  each.value.extra_environment_variables
  )

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# =============================================================================
# EC2 — Nielsen Playwright
# =============================================================================


module "ec2" {
  for_each = var.ec2_instances
  source   = "./modules/ec2"

  instance_name                = each.value.instance_name
  environment                  = var.environment
  instance_type                = each.value.instance_type
  s3_script_bucket             = each.value.s3_script_bucket
  s3_script_prefix             = each.value.s3_script_prefix
  packages                     = each.value.packages
  pip_packages                 = each.value.pip_packages
  install_playwright           = each.value.install_playwright
  startup_script               = each.value.startup_script
  additional_policy_statements = each.value.additional_policy_statements
  depends_on                   = [module.storage]
  
  environment_variables = merge(          # ← keep only this one
    each.value.environment_variables,
    {
      BYZZER_EMAIL    = var.byzzer_email
      BYZZER_PASSWORD = var.byzzer_password
      BYZZER_REPORT   = var.byzzer_report
      RAW_BUCKET_EMAIL = var.raw_bucket_email
    }
  )

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}