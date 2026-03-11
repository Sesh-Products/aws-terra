# =============================================================================
# dev.tfvars — example values for the compute module in a development environment
# Usage: terraform plan -var-file="dev.tfvars"
# =============================================================================

# General
function_name = "aws-terra-etl-pos"
description   = "Python Lambda function — development environment"

tags = {
  Environment = "dev"
  Project     = "aws-terra-pos"
  Team        = "platform"
  CostCenter  = "engineering"
}

# Runtime & code
runtime              = "python3.12"
handler              = "index.handler"
local_zip_deployment = true          # true = use filename + source_code_hash; false = use s3_bucket + s3_key
filename             = "./function.zip"

# Architecture
architectures = ["arm64"] # arm64 is cheaper and faster for Python workloads

# Performance
memory_size                    = 256  # MB
timeout                        = 60   # seconds
ephemeral_storage_size         = 512  # MB (/tmp)
reserved_concurrent_executions = -1   # -1 = no reservation, 0 = throttle all

# Versioning
publish      = true
skip_destroy = false

# IAM
create_iam_role    = true
attach_vpc_policy  = false  # set to true if vpc_config is provided

# Environment variables
environment_variables = {
  ENVIRONMENT = "dev"
  LOG_LEVEL   = "DEBUG"
  APP_NAME    = "aws-terra-pos"
}

# CloudWatch Logs
cloudwatch_log_group_retention_days = 7

# Advanced logging (JSON structured logs with DEBUG level for dev)
logging_config = {
  log_format            = "JSON"
  application_log_level = "DEBUG"
  system_log_level      = "INFO"
}

# Alias
create_alias      = true
alias_name        = "live"
alias_description = "Stable live alias for dev environment"

# Provisioned concurrency (disabled in dev to save cost)
provisioned_concurrent_executions = 0

# Function URL (disabled — use API Gateway instead)
create_function_url = false

# Async invocation settings
maximum_retry_attempts       = 2
maximum_event_age_in_seconds = 3600 # 1 hour

# VPC (disabled in dev — uncomment and fill in for VPC deployment)
# vpc_config = {
#   subnet_ids         = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy"]
#   security_group_ids = ["sg-xxxxxxxxxxxxxxxxx"]
#   ipv6_allowed_for_dual_stack = false
# }

# Dead letter queue (uncomment to enable)
# dead_letter_target_arn = "arn:aws:sqs:us-east-1:123456789012:my-lambda-dlq"

# KMS encryption (uncomment to enable)
# kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Trigger permissions (example: allow API Gateway and S3 to invoke)
# allowed_triggers = {
#   APIGateway = {
#     principal  = "apigateway.amazonaws.com"
#     source_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123/*/*"
#   }
#   S3Bucket = {
#     principal  = "s3.amazonaws.com"
#     source_arn = "arn:aws:s3:::my-trigger-bucket"
#   }
# }