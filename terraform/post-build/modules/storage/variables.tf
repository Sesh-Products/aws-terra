# =============================================================================
# General
# =============================================================================

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket."
  type        = string
}

variable "force_destroy" {
  description = "When true, all objects are deleted from the bucket on destroy so it can be removed without error."
  type        = bool
  default     = false
}

variable "object_lock_enabled" {
  description = "Enable S3 Object Lock on the bucket. Cannot be disabled after creation."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}

# =============================================================================
# Ownership Controls
# =============================================================================

variable "object_ownership" {
  description = "Object ownership rule. BucketOwnerEnforced disables ACLs (recommended). BucketOwnerPreferred or ObjectWriter enable ACLs."
  type        = string
  default     = "BucketOwnerEnforced"

  validation {
    condition     = contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], var.object_ownership)
    error_message = "object_ownership must be BucketOwnerEnforced, BucketOwnerPreferred, or ObjectWriter."
  }
}

# =============================================================================
# Public Access Block
# =============================================================================

variable "block_public_acls" {
  description = "Block public access granted through ACLs."
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public access granted through bucket policies."
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs on the bucket and objects."
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies. Requests by non-AWS services or unauthorised users are blocked."
  type        = bool
  default     = true
}

# =============================================================================
# Versioning
# =============================================================================

variable "versioning_status" {
  description = "Versioning state. Enabled = keep all versions. Suspended = stop creating new versions. Disabled = never versioned."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Suspended", "Disabled"], var.versioning_status)
    error_message = "versioning_status must be Enabled, Suspended, or Disabled."
  }
}

variable "mfa_delete" {
  description = "Require MFA for version deletion. Only valid when versioning_status = Enabled. Enabled or Disabled."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.mfa_delete)
    error_message = "mfa_delete must be Enabled or Disabled."
  }
}

# =============================================================================
# Encryption (Server-Side)
# =============================================================================

variable "sse_algorithm" {
  description = "Server-side encryption algorithm. AES256 = SSE-S3. aws:kms = SSE-KMS (requires kms_master_key_id or uses aws/s3 key)."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be AES256 or aws:kms."
  }
}

variable "kms_master_key_id" {
  description = "ARN or ID of the KMS key to use for SSE-KMS encryption. Defaults to the AWS managed key (aws/s3) when sse_algorithm = aws:kms."
  type        = string
  default     = null
}

variable "bucket_key_enabled" {
  description = "Reduce KMS API calls and cost by enabling an S3 Bucket Key for SSE-KMS. Only applicable when sse_algorithm = aws:kms."
  type        = bool
  default     = false
}

# =============================================================================
# Lifecycle Rules
# =============================================================================

variable "lifecycle_rules" {
  description = <<-EOT
    List of lifecycle rules applied to objects in the bucket.
    Each rule can express expiration, transitions, noncurrent version management,
    and incomplete multipart upload cleanup.
  EOT
  type = list(object({
    id      = string
    enabled = optional(bool, true)

    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))

    expiration = optional(object({
      days                         = optional(number)
      expired_object_delete_marker = optional(bool)
    }))

    noncurrent_version_expiration = optional(object({
      noncurrent_days = number
    }))

    abort_incomplete_multipart_upload = optional(object({
      days_after_initiation = number
    }))

    transitions = optional(list(object({
      days          = optional(number)
      storage_class = string
    })), [])

    noncurrent_version_transitions = optional(list(object({
      noncurrent_days = number
      storage_class   = string
    })), [])
  }))
  default = []
}

# =============================================================================
# Logging
# =============================================================================

variable "logging_target_bucket" {
  description = "Name of the S3 bucket to receive server access logs. Omit to disable logging."
  type        = string
  default     = null
}

variable "logging_target_prefix" {
  description = "Prefix for log object keys. Defaults to the bucket name."
  type        = string
  default     = null
}

# =============================================================================
# CORS
# =============================================================================

variable "cors_rules" {
  description = "List of CORS rules for the bucket. Required when the bucket is used as a website or accessed from browser-based clients."
  type = list(object({
    allowed_headers = optional(list(string), [])
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number)
  }))
  default = []
}

# =============================================================================
# Website Hosting
# =============================================================================

variable "website_config" {
  description = "Static website hosting configuration. Set to enable S3 website endpoint."
  type = object({
    index_document           = string
    error_document           = optional(string)
    redirect_all_requests_to = optional(string)
  })
  default = null
}

# =============================================================================
# Bucket Policy
# =============================================================================

variable "bucket_policy" {
  description = "JSON-encoded IAM policy document to attach to the bucket. Use jsonencode() or a data source."
  type        = string
  default     = null
}

# =============================================================================
# Notifications
# =============================================================================

variable "notification_configuration" {
  description = <<-EOT
    S3 event notification targets.
    - lambda_functions: invoke Lambda on bucket events.
    - queues: send to SQS on bucket events.
    - topics: publish to SNS on bucket events.
    Common events: s3:ObjectCreated:*, s3:ObjectRemoved:*, s3:ObjectRestore:*.
  EOT
  type = object({
    lambda_functions = optional(list(object({
      id            = string
      lambda_arn    = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })), [])
    queues = optional(list(object({
      id            = string
      queue_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })), [])
    topics = optional(list(object({
      id            = string
      topic_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })), [])
  })
  default = null
}

# =============================================================================
# Transfer Acceleration
# =============================================================================

variable "acceleration_status" {
  description = "Transfer acceleration state. Enabled = route uploads via CloudFront edge locations. Suspended = disable."
  type        = string
  default     = null

  validation {
    condition     = var.acceleration_status == null || contains(["Enabled", "Suspended"], var.acceleration_status)
    error_message = "acceleration_status must be Enabled or Suspended."
  }
}

# =============================================================================
# Request Payment
# =============================================================================

variable "request_payer" {
  description = "Who pays for requests. BucketOwner = default. Requester = requester pays model."
  type        = string
  default     = null

  validation {
    condition     = var.request_payer == null || contains(["BucketOwner", "Requester"], var.request_payer)
    error_message = "request_payer must be BucketOwner or Requester."
  }
}

# =============================================================================
# Intelligent Tiering
# =============================================================================

variable "intelligent_tiering_configurations" {
  description = <<-EOT
    List of S3 Intelligent-Tiering archive configurations.
    - archive_access_days: days of no access before moving to Archive Access tier (min 90).
    - deep_archive_access_days: days before moving to Deep Archive Access tier (min 180).
  EOT
  type = list(object({
    name   = string
    status = optional(string, "Enabled")
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    archive_access_days      = optional(number)
    deep_archive_access_days = optional(number)
  }))
  default = []
}
# =============================================================================
# Seed Data — uploads local files to bucket on terraform apply
# =============================================================================

variable "seed_files" {
  description = "Files to upload to the bucket on terraform apply"
  type = map(object({
    local_path   = string
    s3_key       = string
    content_type = optional(string, "text/csv")
  }))
  default = {}
}

# =============================================================================
# Snowflake
# =============================================================================

variable "snowflake_enabled" {
  type    = bool
  default = false
}

variable "snowflake_iam_role_name" {
  type    = string
  default = null
}

variable "snowflake_storage_integration_name" {
  type    = string
  default = null
}

variable "snowflake_database" {
  type    = string
  default = null
}

variable "snowflake_schema" {
  type    = string
  default = null
}

variable "snowflake_table" {
  type    = string
  default = null
}

variable "snowflake_stage_name" {
  type    = string
  default = null
}

variable "snowflake_pipe_name" {
  type    = string
  default = null
}

variable "snowflake_file_format_name" {
  type    = string
  default = null
}

variable "snowflake_stream_name" {
  type    = string
  default = null
}

variable "snowflake_task_schema" {
  type    = string
  default = null
}

variable "snowflake_backup_schema" {
  type    = string
  default = null
}

variable "snowflake_dim_schema" {
  type    = string
  default = null
}

variable "snowflake_fact_schema" {
  type    = string
  default = null
}

variable "snowflake_backup_task_name" {
  type    = string
  default = null
}

variable "snowflake_fact_task_name" {
  type    = string
  default = null
}