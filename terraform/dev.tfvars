# =============================================================================
# Lambda
# =============================================================================
aws_region  = "us-east-1"
environment  = "dev"
project= "pos-pipeline"
lambda_functions = {
  pos_extract_transform  = {
    runtime                        = "python3.12"
    handler                        = "index.handler"
    filename                       = "./builds/pos_extract_transform.zip"
    memory_size                    = 256
    timeout                        = 120
    ephemeral_storage_size         = null
    reserved_concurrent_executions = -1
    architectures                  = ["arm64"]
    publish                        = true
    create_alias                   = false
    log_retention_days             = 14
    log_level                      = "INFO"
    log_group_name = "pos_extract_transform"
    layer_arns = ["arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python312-Arm64:17"]
    additional_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::product-upc-mapping/*"]
    },
    {
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      resources = [
        "arn:aws:s3:::pos-pipeline-dev-data",
        "arn:aws:s3:::pos-pipeline-dev-data/*"
      ]
    },
    {
      effect    = "Allow"
      actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
      resources = [
        "arn:aws:s3:::pos-raw-email-bucket",
        "arn:aws:s3:::pos-raw-email-bucket/*",
        "arn:aws:s3:::pos-processed-email-bucket",
      "arn:aws:s3:::pos-processed-email-bucket/*"
      ]
    }
  ]
  }
}

# =============================================================================
# S3
# =============================================================================

s3_buckets = {s3_bucket_raw = {
    bucket_name                      = "pos-raw-email-bucket"
    force_destroy                    = false
    versioning_status                = "Enabled"
    sse_algorithm                    = "AES256"
    kms_master_key_id                = null
    bucket_key_enabled               = false
    block_public_acls                = true
    block_public_policy              = true
    ignore_public_acls               = true
    restrict_public_buckets          = true
    lifecycle_rules                  = []
    intelligent_tiering_configurations = []
  },
  s3_bucket_transformed = {
    bucket_name                      = "pos-processed-email-bucket"
    force_destroy                    = false
    versioning_status                = "Enabled"
    sse_algorithm                    = "AES256"
    kms_master_key_id                = null
    bucket_key_enabled               = false
    block_public_acls                = true
    block_public_policy              = true
    ignore_public_acls               = true
    restrict_public_buckets          = true
    lifecycle_rules                  = []
    intelligent_tiering_configurations = []
    snowflake_enabled                  = true
    snowflake_iam_role_name            = "snowflake-pos-email-role"
    snowflake_storage_integration_name = "pos_s3_integration"
    snowflake_database                 = "SESH_METADATA"
    snowflake_schema                   = "STG"
    snowflake_table                    = "STG_POS_UNIFIED_DEV"
    snowflake_stage_name               = "pos_unified_stage"
    snowflake_pipe_name                = "pos_snowpipe"
    snowflake_file_format_name         = "pos_csv_format_dev"
    snowflake_stream_name      = "stg_pos_unified_dev_stream"
    snowflake_task_schema      = "TSK"
    snowflake_backup_schema    = "BCK"
    snowflake_dim_schema       = "PUBLIC"
    snowflake_fact_schema      = "PUBLIC"
    snowflake_backup_task_name = "load_pos_backup"
    snowflake_fact_task_name   = "load_fact_pos"
  
  },
  s3_product_upc_mapping = {
    bucket_name                      = "product-upc-mapping"
    force_destroy                    = false
    versioning_status                = "Enabled"
    sse_algorithm                    = "AES256"
    kms_master_key_id                = null
    bucket_key_enabled               = false
    block_public_acls                = true
    block_public_policy              = true
    ignore_public_acls               = true
    restrict_public_buckets          = true
    lifecycle_rules                  = []
    intelligent_tiering_configurations = []
    seed_files                       = {
      "product_sku_mapping"          = {
        local_path   = "../src/Lookup Data/product-upc mapping.csv"
        s3_key       = "product-sku.csv"
        content_type = "text/csv"
      }
    }
  } 
}

# =============================================================================
# Secrets
# =============================================================================

secrets = {
  snowflake_credentials = {
    secret_name             = "snowflake/pos-pipeline/dev/credentials"
    description             = "Snowflake credentials for pos-pipeline"
    recovery_window_in_days = 0
    secret_string           = "{\"organization\":\"JNPMQNX\",\"account\":\"VI43165\",\"username\":\"JACKIE\"}"
  }
  snowflake_private_key = {
    secret_name             = "snowflake/pos-pipeline/dev/private-key"
    description             = "Snowflake RSA private key"
    recovery_window_in_days = 0
    secret_string           = null  # ← handled in main.tf via file()
  }
}