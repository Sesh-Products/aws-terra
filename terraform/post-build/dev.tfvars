
# =============================================================================
# Lambda
# =============================================================================
aws_region  = "us-east-1"
environment  = "dev"
project= "pos-pipeline"

lambda_functions = {
  pos_extract  = {
    function_name                  = "pos_extract-dev"
    source_dir                     = "../../src/Lambdas/pos_extract"
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
      actions   = ["lambda:InvokeFunction"]
      resources = ["arn:aws:lambda:us-east-1:000605313601:function:ses-ec2-trigger-dev"]
    },
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
    NOTIFY_EMAIL = "naimish@seshproducts.com"
    NIELSEN_FROM_EMAIL = "byzzer.services@smb.nielseniq.com"
    EC2_TRIGGER_LAMBDA = "ses-ec2-trigger-dev"
    RAW_BUCKET_EMAIL   = "pos-raw-email-bucket"
    VENDOR_CONFIG = "{\"qt\":{\"keywords\":[\"qt\",\"quiktrip\"],\"file_filter\":[\"pos\"],\"from_email\":[\"drake@seshproducts.com\"],\"missing\":{\"EQ Units\":[\"3.67\"],\"Store\":[\"QT\"]}},\"buc-ees\":{\"keywords\":[\"buc\",\"buc-ees\",\"bucees\"],\"subject_filter\":[\"sesh weekly report\"],\"file_filter\":[\"sesh weekly report\"],\"from_email\":[\"data@seshproducts.com\",\"brandon\"],\"missing\":{\"Store\":[\"Buc-ee's\"]}},\"nielsen\":{\"keywords\":[\"nielsen\",\"niq\",\"rms\"],\"file_filter\":[\"pos\"],\"from_email\":[\"byzzer.services@smb.nielseniq.com\"]}}"
    }
  },
  pos_transform  = {
    function_name                  = "pos_transform-dev"
    source_dir                     = "../../src/Lambdas/pos_transform"
    runtime                        = "python3.12"
    handler                        = "index.handler"
    memory_size                    = 512
    timeout                        = 200
    ephemeral_storage_size         = null
    reserved_concurrent_executions = -1
    architectures                  = ["arm64"]
    publish                        = true
    create_alias                   = false
    log_retention_days             = 14
    log_level                      = "INFO"
    layer_arns = [
    "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python312-Arm64:17"
    ]
    additional_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["ses:SendEmail", "ses:SendRawEmail"]
      resources = ["*"]
    },
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
    },
    {
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [
        "arn:aws:secretsmanager:us-east-1:000605313601:secret:snowflake/pos-pipeline/dev/private-key*",
        "arn:aws:secretsmanager:us-east-1:000605313601:secret:snowflake/pos-pipeline/dev/credentials*"
      ]
    }]
    extra_environment_variables = {
    NOTIFY_EMAIL = "naimish@seshproducts.com"
    TRANSFORMED_BUCKET  = "pos-processed-email-bucket"
    SNOWFLAKE_ACCOUNT   = "JNPMQNX-VI43165"
    SNOWFLAKE_USER      = "JACKIE"
    SNOWFLAKE_DATABASE  = "SESH_METADATA"
    SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
    SNOWFLAKE_ROLE      = "ACCOUNTADMIN"
    COLUMN_CONFIG = "{\"buc-ees\":{\"Trans_date\":\"Week Label\",\"Store_Code\":\"Store_Code\",\"City\":\"Store_Name\",\"Product\":\"Item\",\"EQ_Units\":\"Sale\",\"Product UPC\":\"UPC\"},\"qt\":{\"Trans_date\":\"Trans Date\",\"Store_Code\":\"Store No\",\"Address\":\"Address\",\"City\":\"City\",\"County\":\"County\",\"State\":\"State\",\"Postal_Code\":\"Postal Code\",\"Product UPC\":\"Vendor Item #\",\"Product\":\"Item Description\",\"Sales\":\"Total Sales Dollars\"},\"nielsen\":{\"Trans_date\":\"Date\",\"Product UPC\":\"UPC\",\"Product\":\"Product Description\",\"Sales\":\"Total $ Sales\",\"EQ_Units\":\"Total EQ Unit Sales\",\"Store_Name\":\"Markets\"}}"
    VENDOR_CONFIG = "{\"qt\":{\"keywords\":[\"qt\",\"quiktrip\"],\"file_filter\":[\"pos\"],\"from_email\":[\"drake@seshproducts.com\"],\"missing\":{\"EQ Units\":[\"3.67\"],\"Store\":[\"QT\"]}},\"buc-ees\":{\"keywords\":[\"buc\",\"buc-ees\",\"bucees\"],\"subject_filter\":[\"sesh weekly report\"],\"file_filter\":[\"sesh weekly report\"],\"from_email\":[\"data@seshproducts.com\",\"brandon\"],\"missing\":{\"Store\":[\"Buc-ee's\"]}},\"nielsen\":{\"keywords\":[\"nielsen\",\"niq\",\"rms\"],\"file_filter\":[\"pos\"],\"from_email\":[\"byzzer.services@smb.nielseniq.com\"]}}"
    }
    allowed_triggers = {
    S3RawBucket = {
      principal  = "s3.amazonaws.com"
      source_arn = "arn:aws:s3:::pos-raw-email-bucket"
    }
    }
  },
  ses_ec2_trigger = {
  function_name  = "ses-ec2-trigger-dev"
  source_dir     = "../../src/Lambdas/ses_ec2_trigger_dev"
  runtime        = "python3.12"
  handler        = "index.handler"
  memory_size    = 128
  timeout        = 30
  architectures  = ["arm64"]
  publish        = true
  create_alias   = false
  log_retention_days = 14
  log_level      = "INFO"
  layer_arns     = []
  extra_environment_variables = {
    EC2_INSTANCE_NAME = "nielsen-playwright-dev"
  }
  additional_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["ssm:SendCommand", "ssm:GetCommandInvocation"]
      resources = ["*"]
    },
    {
      effect    = "Allow"
      actions   = ["ec2:DescribeInstances"]
      resources = ["*"]
    }
  ]
  }
  }


# =============================================================================
# Lambda Layers
# =============================================================================

lambda_layers = {
  snowflake_connector = {
    layer_name               = "snowflake-connector-layer"
    source_dir               = "../../src/Layers/snowflake"
    description              = "Snowflake Python connector"
    compatible_runtimes      = ["python3.12"]
    compatible_architectures = ["arm64"]
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
        local_path   = "../../src/Ec2/Nielsen-playwright/index.py"
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

    bucket_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"AllowSESPuts\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ses.amazonaws.com\"},\"Action\":\"s3:PutObject\",\"Resource\":\"arn:aws:s3:::pos-raw-email-bucket/*\"}]}"
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

# =============================================================================
# SES
# =============================================================================

ses_domain              = "data.seshproducts.com"
ses_email_identities    = ["naimish@seshproducts.com", "data-ingest@seshproducts.com"]
ses_rule_set_name       = "pos_extract_trigger_dev"
ses_rule_name           = "pos_extract_trigger_dev"
ses_rule_recipients     = ["data.seshproducts.com"]
ses_s3_bucket_name      = "pos-raw-email-bucket"
ses_s3_key_prefix       = "ses-emails/"
ses_lambda_function_arn = "arn:aws:lambda:us-east-1:000605313601:function:pos_extract-dev"

