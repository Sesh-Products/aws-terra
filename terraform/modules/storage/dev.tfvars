# =============================================================================
# dev.tfvars — example values for the storage module in a development environment
# Usage: terraform plan -var-file="dev.tfvars"
# =============================================================================

# General
bucket_name   = "aws-terra-dev-data"
force_destroy = true  # safe to destroy non-empty bucket in dev

tags = {
  Environment = "dev"
  Project     = "aws-terra"
  Team        = "data-engineering"
}

# Ownership
object_ownership = "BucketOwnerEnforced"  # disables ACLs (recommended)

# Public Access Block (all blocked — default and recommended)
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true

# Versioning
versioning_status = "Enabled"
mfa_delete        = "Disabled"

# Encryption
sse_algorithm      = "AES256"  # switch to aws:kms and provide kms_master_key_id for KMS
kms_master_key_id  = null
bucket_key_enabled = false

# Lifecycle rules (example: move to IA after 30 days, expire after 90 days)
lifecycle_rules = [
  {
    id      = "dev-cleanup"
    enabled = true
    filter = {
      prefix = "tmp/"
    }
    expiration = {
      days = 30
    }
    abort_incomplete_multipart_upload = {
      days_after_initiation = 7
    }
  }
]

# Logging (uncomment to enable — requires a separate logging bucket)
# logging_target_bucket = "aws-terra-dev-logs"
# logging_target_prefix = "s3/aws-terra-dev-data/"

# CORS (uncomment to enable browser access)
# cors_rules = [
#   {
#     allowed_methods = ["GET", "PUT"]
#     allowed_origins = ["https://example.com"]
#     allowed_headers = ["*"]
#     max_age_seconds = 3600
#   }
# ]

# Website (uncomment to enable static hosting)
# website_config = {
#   index_document = "index.html"
#   error_document = "error.html"
# }

# Bucket policy (uncomment to attach a custom policy)
# bucket_policy = jsonencode({ ... })

# Notifications (uncomment to enable event-driven triggers)
# notification_configuration = {
#   lambda_functions = [
#     {
#       id         = "on-upload"
#       lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:my-function"
#       events     = ["s3:ObjectCreated:*"]
#       filter_prefix = "uploads/"
#     }
#   ]
#   queues = []
#   topics = []
# }

# Transfer acceleration (uncomment to enable)
# acceleration_status = "Enabled"

# Request payment (uncomment to enable requester-pays)
# request_payer = "Requester"

# Intelligent Tiering (uncomment to enable)
# intelligent_tiering_configurations = [
#   {
#     name                 = "archive-old-objects"
#     archive_access_days      = 90
#     deep_archive_access_days = 180
#   }
# ]
