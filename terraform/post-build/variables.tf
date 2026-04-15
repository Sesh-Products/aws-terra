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
    source_dir               = string
    description              = optional(string, "")
    license_info             = optional(string, null)
    compatible_runtimes      = optional(list(string), [])
    compatible_architectures = optional(list(string), ["x86_64"])
    skip_destroy             = optional(bool, false)
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
    seed_files                       = optional(map(object({
      local_path                     = string
      s3_key                         = string
      content_type                   = optional(string, "text/csv")
    })), {})
    snowflake_enabled                  = optional(bool, false)
    snowflake_iam_role_name            = optional(string, null)
    snowflake_storage_integration_name = optional(string, null)
    snowflake_database                 = optional(string, null)
    snowflake_schema                   = optional(string, null)
    snowflake_table                    = optional(string, null)
    snowflake_stage_name               = optional(string, null)
    snowflake_pipe_name                = optional(string, null)
    snowflake_file_format_name         = optional(string, null)
    snowflake_iam_user_arn             = optional(string, null)
    snowflake_external_id              = optional(string, null)
    snowflake_stream_name              = optional(string, null)
    snowflake_task_schema              = optional(string, null)
    snowflake_backup_schema            = optional(string, null)
    snowflake_dim_schema               = optional(string, null)
    snowflake_fact_schema              = optional(string, null)
    snowflake_backup_task_name         = optional(string, null)
    snowflake_fact_task_name           = optional(string, null)
    bucket_policy = optional(string, null)
    notification_configuration = optional(object({
    lambda_functions = optional(list(object({
      id            = string
      lambda_arn    = string
      events        = list(string)
      filter_prefix = optional(string, null)
      filter_suffix = optional(string, null)
    })), [])
}), null)
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
    function_name                  = optional(string, null)
    runtime                        = optional(string, "python3.12")
    handler                        = optional(string, "index.handler")
    source_file                    = optional(string, "../src/Lambdas/pos_extract_transform/index.py")
    source_dir                     = optional(string)
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
    extra_environment_variables    = optional(map(string), {})

    allowed_triggers = optional(map(object({
      statement_id   = optional(string)
      action         = optional(string, "lambda:InvokeFunction")
      principal      = string
      source_arn     = optional(string)
      source_account = optional(string)
      qualifier      = optional(string)
    })), {})

    additional_policy_statements   = optional(list(object({
      effect    = string
      actions   = list(string)
      resources = list(string)
    })), [])
  }))
  default = {
  }
}


# =============================================================================
# EC2
# =============================================================================

variable "ec2_instances" {
  type = map(object({
    instance_name                = string
    instance_type                = optional(string, "t4g.nano")
    s3_script_bucket             = optional(string, "pos-raw-email-bucket")
    s3_script_prefix             = optional(string, "ec2-scripts")
    packages                     = optional(list(string), [])
    pip_packages                 = optional(list(string), [])
    install_playwright           = optional(bool, false)
    startup_script               = optional(string, "")
    environment_variables        = optional(map(string), {})
    additional_policy_statements = optional(list(object({
      effect    = string
      actions   = list(string)
      resources = list(string)
    })), [])
  }))
  default = {}
}

variable "byzzer_email" {
  type    = string
  sensitive = true
  default = null
}

variable "byzzer_password" {
  type      = string
  sensitive = true
  default   = null
}

variable "byzzer_report" {
  type    = string
  default = null
}

variable "raw_bucket_email" {
  sensitive = true
  type        = string
  default     = null
}

# =============================================================================
# SES
# =============================================================================

variable "ses_domain" {
  description = "Domain to verify in SES"
  type        = string
  default     = null
}

variable "ses_email_identities" {
  description = "List of email addresses to verify in SES"
  type        = list(string)
  default     = []
}

variable "ses_rule_set_name" {
  description = "Name of the SES receipt rule set"
  type        = string
  default     = null
}

variable "ses_rule_name" {
  description = "Name of the SES receipt rule"
  type        = string
  default     = null
}

variable "ses_rule_recipients" {
  description = "Recipient domains or emails for the SES receipt rule"
  type        = list(string)
  default     = []
}

variable "ses_s3_bucket_name" {
  description = "S3 bucket for raw SES emails"
  type        = string
  default     = null
}

variable "ses_s3_key_prefix" {
  description = "S3 key prefix for SES emails"
  type        = string
  default     = "ses-emails/"
}

variable "ses_lambda_function_arn" {
  description = "ARN of Lambda triggered by SES receipt rule"
  type        = string
  default     = null
}

# =============================================================================
# DKIM Output
# =============================================================================

variable "dkim_output_dir" {
  description = "Local directory path where dkim_records.txt will be saved"
  type        = string
  default     = "./dkim-records"
}