# =============================================================================
# Lambda
# =============================================================================
aws_region  = "us-east-1"
environment  = "dev"
project= "pos-pipeline"
snowflake_private_key_path = "C:\\SESH\\ETL Automation\\snowflake-schema_change\\rsa_key.p8"  # ← add here

lambda_functions = {
  pos_extract  = {
    function_name                  = "pos_extract-dev"
    source_dir                     = "../src/Lambdas/pos_extract"
    runtime                        = "python3.12"
    handler                        = "index.handler"
    memory_size                    = 256
    timeout                        = 120
    ephemeral_storage_size         = null
    reserved_concurrent_executions = -1
    architectures                  = ["arm64"]
    publish                        = true
    create_alias                   = false
    log_retention_days             = 14
    log_level                      = "INFO"
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
    }]
    extra_environment_variables = {
    RAW_BUCKET_EMAIL   = "pos-raw-email-bucket"
    VENDOR_CONFIG      = "{\"qt\":{\"keywords\":[\"qt\",\"quiktrip\"],\"file_filter\":[\"pos\"],\"missing\":{\"EQ Units\":[\"3.67\"],\"Store\":[\"QT\"]}},\"buc-ees\":{\"keywords\":[\"buc\",\"buc-ees\",\"bucees\"],\"subject_filter\":[\"sesh weekly report\"],\"file_filter\":[\"sesh weekly report\"],\"missing\":{\"Store\":[\"Buc-ee's\"]}},\"nielsen\":{\"keywords\":[\"nielsen\",\"niq\",\"rms\"],\"file_filter\":[\"pos\"]}}"
    }
  },
  pos_transform  = {
    function_name                  = "pos_transform-dev"
    source_dir                     = "../src/Lambdas/pos_transform"
    runtime                        = "python3.12"
    handler                        = "index.handler"
    memory_size                    = 256
    timeout                        = 120
    ephemeral_storage_size         = null
    reserved_concurrent_executions = -1
    architectures                  = ["arm64"]
    publish                        = true
    create_alias                   = false
    log_retention_days             = 14
    log_level                      = "INFO"
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
    }]
    extra_environment_variables = {
    TRANSFORMED_BUCKET = "pos-processed-email-bucket"
    COLUMN_CONFIG = "{\"buc-ees\":{\"Trans_date\":\"Week Label\",\"Store_Code\":\"Store_Code\",\"Store_Name\":\"Store_Name\",\"Product\":\"Item\",\"EQ_Units\":\"Sale\",\"Product UPC\":\"UPC\"},\"qt\":{\"Trans_date\":\"Trans Date\",\"Store_Code\":\"Store No\",\"Address\":\"Address\",\"City\":\"City\",\"County\":\"County\",\"State\":\"State\",\"Postal_Code\":\"Postal Code\",\"Product UPC\":\"Vendor Item #\",\"Product\":\"Item Description\",\"Sales\":\"Total Sales Dollars\"},\"nielsen\":{\"Trans_date\":\"Date\",\"Product UPC\":\"UPC\",\"Product\":\"Product Description\",\"Sales\":\"Total $ Sales\",\"EQ_Units\":\"Total EQ Unit Sales\",\"Store_Name\":\"Markets\"}}"
    VENDOR_CONFIG      = "{\"qt\":{\"keywords\":[\"qt\",\"quiktrip\"],\"file_filter\":[\"pos\"],\"missing\":{\"EQ Units\":[\"3.67\"],\"Store\":[\"QT\"]}},\"buc-ees\":{\"keywords\":[\"buc\",\"buc-ees\",\"bucees\"],\"subject_filter\":[\"sesh weekly report\"],\"file_filter\":[\"sesh weekly report\"],\"missing\":{\"Store\":[\"Buc-ee's\"]}},\"nielsen\":{\"keywords\":[\"nielsen\",\"niq\",\"rms\"],\"file_filter\":[\"pos\"]}}"
    }
    allowed_triggers = {
    S3RawBucket = {
      principal  = "s3.amazonaws.com"
      source_arn = "arn:aws:s3:::pos-raw-email-bucket"
    }
  } 
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
    seed_files = {
      "nielsen_index" = {
        local_path   = "../src/Lambdas/Nielsen-playwright/index.py"
        s3_key       = "ec2-scripts/nielsen/index.py"
        content_type = "text/x-python"
      }
    }
    notification_configuration = {
    lambda_functions = [
      {
        id            = "pos-transform-trigger"
        lambda_arn    = "arn:aws:lambda:us-east-1:000605313601:function:pos_transform-dev"
        events        = ["s3:ObjectCreated:*"]
        filter_prefix = "pos-files/"
        filter_suffix = null
      }
    ]}
  },
  s3_bucket_transformed = {
    bucket_name                      = "pos-processed-email-bucket"
    force_destroy                    = true
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
    force_destroy                    = true
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

# =============================================================================
# EC2
# =============================================================================

ec2_instances = {
  nielsen_playwright = {
    instance_name      = "nielsen-playwright-dev"
    instance_type      = "t4g.small"
    s3_script_bucket   = "pos-raw-email-bucket"
    s3_script_prefix   = "ec2-scripts/nielsen"
    install_playwright = true                    
    pip_packages       = ["boto3"]                
    environment_variables = {
      BYZZER_EMAIL     = "data-ingest@seshproducts.com"
      BYZZER_PASSWORD  = "DataAdmin2026@sesh"
      BYZZER_REPORT    = "Sesh KA & Markets Data Sets (03.14.26) - Tableau 1.0 w/e 03/07/2026"
      RAW_BUCKET_EMAIL = "pos-raw-email-bucket"
    }
    additional_policy_statements = [
      {
        effect  = "Allow"
        actions = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        resources = [
          "arn:aws:s3:::pos-raw-email-bucket",
          "arn:aws:s3:::pos-raw-email-bucket/*"
        ]
      }
    ]
  }
}