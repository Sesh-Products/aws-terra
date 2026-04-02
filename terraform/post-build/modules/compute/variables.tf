# =============================================================================
# General
# =============================================================================

variable "function_name" {
  description = "Unique name for the Lambda function"
  type        = string
}

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Runtime & Code Source
# =============================================================================

variable "runtime" {
  description = "Lambda runtime. Defaults to python3.12. Other supported: python3.8, python3.9, python3.10, python3.11"
  type        = string
  default     = "python3.12"

  validation {
    condition = contains([
      "python3.8", "python3.9", "python3.10", "python3.11", "python3.12",
      "nodejs18.x", "nodejs20.x",
      "java17", "java21",
      "dotnet6", "dotnet8",
      "ruby3.2", "ruby3.3",
      "provided.al2", "provided.al2023"
    ], var.runtime)
    error_message = "Must be a valid AWS Lambda runtime identifier."
  }
}

variable "handler" {
  description = "Function entrypoint in format file.function (e.g. index.handler)"
  type        = string
  default     = "index.handler"
}

variable "package_type" {
  description = "Lambda deployment package type. Valid values: Zip, Image. No container image support in this module — keep as Zip."
  type        = string
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be Zip or Image."
  }
}

variable "local_zip_deployment" {
  description = "Set to true to deploy from a local zip file (filename + source_code_hash). Set to false to deploy from S3 (s3_bucket + s3_key)."
  type        = bool
  default     = true
}

# --- Local zip deployment ---
variable "filename" {
  description = "Path to the local .zip file containing function code. Conflicts with s3_bucket/s3_key."
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the zip file. Forces re-deploy on change. Use filebase64sha256()."
  type        = string
  default     = null
}

# --- S3 deployment ---
variable "s3_bucket" {
  description = "S3 bucket containing the deployment package. Conflicts with filename."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 object key of the deployment package."
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Specific version of the S3 deployment package object."
  type        = string
  default     = null
}

# =============================================================================
# Architecture & Performance
# =============================================================================

variable "architectures" {
  description = "Instruction set architecture list. Valid values: x86_64, arm64."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = alltrue([for a in var.architectures : contains(["x86_64", "arm64"], a)])
    error_message = "Each architecture must be x86_64 or arm64."
  }
}

variable "memory_size" {
  description = "Amount of memory (MB) allocated to the Lambda function. Min: 128, Max: 10240."
  type        = number
  default     = 1024

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Execution timeout in seconds. Min: 1, Max: 900."
  type        = number
  default     = 900

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "ephemeral_storage_size" {
  description = "Size of the /tmp directory in MB. Min: 512, Max: 10240. Omit to use the AWS default (512 MB)."
  type        = number
  default     = null

  validation {
    condition     = var.ephemeral_storage_size == null || (var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240)
    error_message = "ephemeral_storage_size must be between 512 and 10240 MB."
  }
}

variable "reserved_concurrent_executions" {
  description = "Max concurrent executions to reserve for this function. -1 removes any reservation (default). 0 throttles all invocations."
  type        = number
  default     = -1
}

# =============================================================================
# Versioning & Publishing
# =============================================================================

variable "publish" {
  description = "Set to true to publish a new numbered version on every deployment."
  type        = bool
  default     = false
}

variable "skip_destroy" {
  description = "When true, Terraform will not delete the Lambda function on destroy. Useful for production guards."
  type        = bool
  default     = false
}

# =============================================================================
# IAM Role
# =============================================================================

variable "create_iam_role" {
  description = "When true, creates a new IAM execution role for the Lambda. Set to false to supply an existing role via iam_role_arn."
  type        = bool
  default     = true
}

variable "iam_role_arn" {
  description = "ARN of an existing IAM role to assign to Lambda. Only used when create_iam_role = false."
  type        = string
  default     = null
}

variable "iam_role_name" {
  description = "Override the auto-generated IAM role name. Defaults to <function_name>-role."
  type        = string
  default     = null
}

variable "attach_vpc_policy" {
  description = "Attach AWSLambdaVPCAccessExecutionRole managed policy. Required when vpc_config is set."
  type        = bool
  default     = false
}

variable "additional_policy_statements" {
  description = "List of additional IAM policy statements to attach to the Lambda execution role."
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

# =============================================================================
# Environment Variables
# =============================================================================

variable "environment_variables" {
  description = "Map of environment variable key/value pairs injected into the Lambda runtime."
  type        = map(string)
  default     = null
}

# =============================================================================
# Encryption
# =============================================================================

variable "kms_key_arn" {
  description = "ARN of a KMS key used to encrypt environment variables and CloudWatch logs at rest."
  type        = string
  default     = null
}

# =============================================================================
# VPC Configuration
# =============================================================================

variable "vpc_config" {
  description = "Place the Lambda function inside a VPC. Requires attach_vpc_policy = true."
  type = object({
    subnet_ids                  = list(string)
    security_group_ids          = list(string)
    ipv6_allowed_for_dual_stack = optional(bool, false)
  })
  default = null
}

variable "replace_security_groups_on_destroy" {
  description = "When destroying a VPC-attached Lambda, replace its security groups with replacement_security_group_ids before deletion."
  type        = bool
  default     = null
}

variable "replacement_security_group_ids" {
  description = "List of security group IDs to substitute when replace_security_groups_on_destroy = true."
  type        = list(string)
  default     = null
}

# =============================================================================
# Dead Letter Queue
# =============================================================================

variable "dead_letter_target_arn" {
  description = "ARN of an SQS queue or SNS topic that receives unprocessable events (dead-letter destination)."
  type        = string
  default     = null
}

# =============================================================================
# Logging
# =============================================================================

variable "cloudwatch_log_group_retention_days" {
  description = "Retention period for CloudWatch logs in days. 0 = never expire. Common values: 1, 3, 7, 14, 30, 60, 90, 180, 365."
  type        = number
  default     = 14
}

variable "logging_config" {
  description = <<-EOT
    Advanced logging configuration for the Lambda function.
    - log_format: "JSON" enables structured logging; "Text" uses plain text (default).
    - log_group: custom CloudWatch log group name. Defaults to /aws/lambda/<function_name>.
    - application_log_level: only valid when log_format = "JSON". One of TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
    - system_log_level: only valid when log_format = "JSON". One of DEBUG, INFO, WARN.
  EOT
  type = object({
    log_format            = string
    log_group             = optional(string)
    application_log_level = optional(string)
    system_log_level      = optional(string)
  })
  default = null

  validation {
    condition     = var.logging_config == null || contains(["JSON", "Text"], try(var.logging_config.log_format, ""))
    error_message = "logging_config.log_format must be JSON or Text."
  }
}

# =============================================================================
# EFS File System
# =============================================================================

variable "file_system_config" {
  description = "Mount an EFS access point into the Lambda execution environment."
  type = object({
    arn              = string # EFS access point ARN
    local_mount_path = string # Must start with /mnt/
  })
  default = null
}

# =============================================================================
# Alias
# =============================================================================

variable "create_alias" {
  description = "Create a Lambda alias pointing to the latest published version (or $LATEST when publish = false)."
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Name for the Lambda alias (e.g. live, stable, v1)."
  type        = string
  default     = "live"
}

variable "alias_description" {
  description = "Human-readable description for the Lambda alias."
  type        = string
  default     = ""
}

variable "alias_routing_config" {
  description = "Weighted routing between two versions. Map of version number -> weight (0.0 - 1.0). E.g. { \"2\" = 0.1 }."
  type        = map(number)
  default     = null
}

# =============================================================================
# Provisioned Concurrency
# =============================================================================

variable "provisioned_concurrent_executions" {
  description = "Number of execution environments to keep warm. Requires publish = true. 0 disables."
  type        = number
  default     = 0
}

# =============================================================================
# Function URL
# =============================================================================

variable "create_function_url" {
  description = "Expose the Lambda function via a direct HTTPS endpoint (Function URL)."
  type        = bool
  default     = false
}

variable "function_url_authorization_type" {
  description = "Controls who can invoke the Function URL. AWS_IAM = only IAM-signed requests. NONE = public."
  type        = string
  default     = "AWS_IAM"

  validation {
    condition     = contains(["NONE", "AWS_IAM"], var.function_url_authorization_type)
    error_message = "function_url_authorization_type must be NONE or AWS_IAM."
  }
}

variable "function_url_invoke_mode" {
  description = "Response mode for the Function URL. BUFFERED = wait for complete response. RESPONSE_STREAM = stream as data arrives."
  type        = string
  default     = "BUFFERED"

  validation {
    condition     = contains(["BUFFERED", "RESPONSE_STREAM"], var.function_url_invoke_mode)
    error_message = "function_url_invoke_mode must be BUFFERED or RESPONSE_STREAM."
  }
}

variable "function_url_cors" {
  description = "CORS configuration for the Function URL."
  type = object({
    allow_credentials = optional(bool, false)
    allow_headers     = optional(list(string), [])
    allow_methods     = optional(list(string), ["*"])
    allow_origins     = optional(list(string), ["*"])
    expose_headers    = optional(list(string), [])
    max_age           = optional(number, 0)
  })
  default = null
}

# =============================================================================
# Asynchronous Invocation
# =============================================================================

variable "maximum_event_age_in_seconds" {
  description = "Maximum time (seconds) Lambda retains an async event before discarding. Range: 60–21600."
  type        = number
  default     = null
}

variable "maximum_retry_attempts" {
  description = "Maximum number of retry attempts for failed async invocations. Range: 0–2."
  type        = number
  default     = null
}

variable "destination_on_success_arn" {
  description = "ARN of the destination (SQS, SNS, Lambda, EventBridge) for successful async invocations."
  type        = string
  default     = null
}

variable "destination_on_failure_arn" {
  description = "ARN of the destination (SQS, SNS, Lambda, EventBridge) for failed async invocations."
  type        = string
  default     = null
}

# =============================================================================
# Layers
# =============================================================================

variable "layer_arns" {
  description = "List of Lambda layer version ARNs to attach to the function. Maximum of 5 layers."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.layer_arns) <= 5
    error_message = "A Lambda function can have at most 5 layers attached."
  }
}

# =============================================================================
# Lambda Permissions (Triggers)
# =============================================================================

variable "allowed_triggers" {
  description = <<-EOT
    Map of aws_lambda_permission resources to create. Each key becomes the statement ID suffix.
    Example:
      allowed_triggers = {
        APIGateway = {
          principal  = "apigateway.amazonaws.com"
          source_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123/*/*"
        }
        S3Bucket = {
          principal  = "s3.amazonaws.com"
          source_arn = "arn:aws:s3:::my-bucket"
        }
      }
  EOT
  type = map(object({
    statement_id   = optional(string)
    action         = optional(string, "lambda:InvokeFunction")
    principal      = string
    source_arn     = optional(string)
    source_account = optional(string)
    qualifier      = optional(string)
  }))
  default = {}
}