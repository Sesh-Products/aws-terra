# =============================================================================
# S3 Bucket
# =============================================================================

resource "aws_s3_bucket" "this" {
  bucket              = var.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled

  tags = var.tags
}

# =============================================================================
# Ownership Controls
# =============================================================================

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = var.object_ownership
  }
}

# =============================================================================
# Public Access Block
# =============================================================================

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# =============================================================================
# Versioning
# =============================================================================

resource "aws_s3_bucket_versioning" "this" {
  count = var.versioning_status != "Disabled" ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status     = var.versioning_status
    mfa_delete = var.mfa_delete
  }
}

# =============================================================================
# Server-Side Encryption
# =============================================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = var.bucket_key_enabled

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.kms_master_key_id
    }
  }
}

# =============================================================================
# Lifecycle Rules
# =============================================================================

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "filter" {
        for_each = rule.value.filter != null ? [rule.value.filter] : []
        content {
          prefix = filter.value.prefix

          dynamic "tag" {
            for_each = filter.value.tags != null ? filter.value.tags : {}
            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration != null ? [rule.value.expiration] : []
        content {
          days                         = expiration.value.days
          expired_object_delete_marker = expiration.value.expired_object_delete_marker
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration != null ? [rule.value.noncurrent_version_expiration] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value.noncurrent_days
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload != null ? [rule.value.abort_incomplete_multipart_upload] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value.days_after_initiation
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions
        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }
    }
  }
}

# =============================================================================
# Logging
# =============================================================================

resource "aws_s3_bucket_logging" "this" {
  count = var.logging_target_bucket != null ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_target_bucket
  target_prefix = coalesce(var.logging_target_prefix, "${var.bucket_name}/")
}

# =============================================================================
# CORS
# =============================================================================

resource "aws_s3_bucket_cors_configuration" "this" {
  count = length(var.cors_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# =============================================================================
# Website Hosting
# =============================================================================

resource "aws_s3_bucket_website_configuration" "this" {
  count = var.website_config != null ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "index_document" {
    for_each = var.website_config.redirect_all_requests_to == null ? [1] : []
    content {
      suffix = var.website_config.index_document
    }
  }

  dynamic "error_document" {
    for_each = var.website_config.error_document != null && var.website_config.redirect_all_requests_to == null ? [1] : []
    content {
      key = var.website_config.error_document
    }
  }

  dynamic "redirect_all_requests_to" {
    for_each = var.website_config.redirect_all_requests_to != null ? [1] : []
    content {
      host_name = var.website_config.redirect_all_requests_to
    }
  }
}

# =============================================================================
# Bucket Policy
# =============================================================================

resource "aws_s3_bucket_policy" "this" {
  count = var.bucket_policy != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# =============================================================================
# Notifications
# =============================================================================

resource "aws_s3_bucket_notification" "this" {
  count = var.notification_configuration != null ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "lambda_function" {
    for_each = var.notification_configuration.lambda_functions
    content {
      id                  = lambda_function.value.id
      lambda_function_arn = lambda_function.value.lambda_arn
      events              = lambda_function.value.events

      filter_prefix = lambda_function.value.filter_prefix
      filter_suffix = lambda_function.value.filter_suffix
    }
  }

  dynamic "queue" {
    for_each = var.notification_configuration.queues
    content {
      id        = queue.value.id
      queue_arn = queue.value.queue_arn
      events    = queue.value.events

      filter_prefix = queue.value.filter_prefix
      filter_suffix = queue.value.filter_suffix
    }
  }

  dynamic "topic" {
    for_each = var.notification_configuration.topics
    content {
      id        = topic.value.id
      topic_arn = topic.value.topic_arn
      events    = topic.value.events

      filter_prefix = topic.value.filter_prefix
      filter_suffix = topic.value.filter_suffix
    }
  }
}

# =============================================================================
# Transfer Acceleration
# =============================================================================

resource "aws_s3_bucket_accelerate_configuration" "this" {
  count = var.acceleration_status != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  status = var.acceleration_status
}

# =============================================================================
# Request Payment
# =============================================================================

resource "aws_s3_bucket_request_payment_configuration" "this" {
  count = var.request_payer != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  payer  = var.request_payer
}

# =============================================================================
# Intelligent Tiering
# =============================================================================

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = { for cfg in var.intelligent_tiering_configurations : cfg.name => cfg }

  bucket = aws_s3_bucket.this.id
  name   = each.value.name
  status = each.value.status

  dynamic "filter" {
    for_each = each.value.filter != null ? [each.value.filter] : []
    content {
      prefix = filter.value.prefix
      tags   = filter.value.tags
    }
  }

  dynamic "tiering" {
    for_each = each.value.archive_access_days != null ? [each.value.archive_access_days] : []
    content {
      access_tier = "ARCHIVE_ACCESS"
      days        = tiering.value
    }
  }

  dynamic "tiering" {
    for_each = each.value.deep_archive_access_days != null ? [each.value.deep_archive_access_days] : []
    content {
      access_tier = "DEEP_ARCHIVE_ACCESS"
      days        = tiering.value
    }
  }
}
