terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    snowflake = {
      source = "Snowflake-Labs/snowflake"
    }
  }
}
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

locals {
  # Merge Lambda triggers from notification_configuration + Snowpipe SQS queue into one resource.
  # AWS only allows a single aws_s3_bucket_notification per bucket.
  has_notification = var.notification_configuration != null || var.snowflake_enabled

  notification_lambdas = var.notification_configuration != null ? var.notification_configuration.lambda_functions : []
  notification_queues  = var.notification_configuration != null ? var.notification_configuration.queues : []
  notification_topics  = var.notification_configuration != null ? var.notification_configuration.topics : []
}

resource "aws_s3_bucket_notification" "this" {
  count = local.has_notification ? 1 : 0

  bucket = aws_s3_bucket.this.id

  # Lambda triggers from notification_configuration
  dynamic "lambda_function" {
    for_each = local.notification_lambdas
    content {
      id                  = lambda_function.value.id
      lambda_function_arn = lambda_function.value.lambda_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }

  # SQS queues from notification_configuration
  dynamic "queue" {
    for_each = local.notification_queues
    content {
      id            = queue.value.id
      queue_arn     = queue.value.queue_arn
      events        = queue.value.events
      filter_prefix = queue.value.filter_prefix
      filter_suffix = queue.value.filter_suffix
    }
  }

  # Snowpipe SQS queue (merged in when snowflake_enabled)
  dynamic "queue" {
    for_each = var.snowflake_enabled ? [1] : []
    content {
      id            = "snowpipe-queue"
      queue_arn     = snowflake_pipe.this[0].notification_channel
      events        = ["s3:ObjectCreated:*"]
      filter_suffix = ".csv"
    }
  }

  # SNS topics from notification_configuration
  dynamic "topic" {
    for_each = local.notification_topics
    content {
      id            = topic.value.id
      topic_arn     = topic.value.topic_arn
      events        = topic.value.events
      filter_prefix = topic.value.filter_prefix
      filter_suffix = topic.value.filter_suffix
    }
  }

  depends_on = [snowflake_pipe.this]
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

# =============================================================================
# Seed Data — uploads local files to bucket on terraform apply
# =============================================================================

resource "aws_s3_object" "seed_files" {
  for_each = var.seed_files

  bucket       = aws_s3_bucket.this.id
  key          = each.value.s3_key
  source       = each.value.local_path
  etag         = filemd5(each.value.local_path)
  content_type = each.value.content_type

  tags = var.tags
}

# =============================================================================
# Snowflake Integration
# =============================================================================

resource "aws_iam_role" "snowflake" {
  count = var.snowflake_enabled ? 1 : 0
  name  = var.snowflake_iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::000605313601:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags

  lifecycle {
    ignore_changes = [assume_role_policy]  # ← Terraform never touches this after creation
  }
}

resource "aws_iam_role_policy" "snowflake_s3" {
  count = var.snowflake_enabled ? 1 : 0
  name  = "${var.snowflake_iam_role_name}-s3-policy"
  role  = aws_iam_role.snowflake[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.bucket_name}",
        "arn:aws:s3:::${var.bucket_name}/*"
      ]
    }]
  })
}

# =============================================================================
# SQS Queue for Snowpipe
# =============================================================================

resource "aws_sqs_queue" "snowpipe" {
  count                      = var.snowflake_enabled ? 1 : 0
  name                       = "${var.bucket_name}-snowpipe-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  tags                       = var.tags
}

resource "aws_sqs_queue_policy" "snowpipe" {
  count     = var.snowflake_enabled ? 1 : 0
  queue_url = aws_sqs_queue.snowpipe[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.snowpipe[0].arn
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:s3:::${var.bucket_name}"
        }
      }
    }]
  })
}



# =============================================================================
# Snowflake Storage Integration
# =============================================================================

resource "snowflake_storage_integration" "this" {
  count   = var.snowflake_enabled ? 1 : 0
  name    = var.snowflake_storage_integration_name
  type    = "EXTERNAL_STAGE"
  enabled = true

  storage_provider          = "S3"
  storage_aws_role_arn      = aws_iam_role.snowflake[0].arn
  storage_allowed_locations = ["s3://${var.bucket_name}/"]

  depends_on = [aws_iam_role.snowflake]
}

# =============================================================================
# Snowflake File Format
# =============================================================================

resource "snowflake_file_format" "csv" {
  count                          = var.snowflake_enabled ? 1 : 0
  name                           = var.snowflake_file_format_name
  database                       = var.snowflake_database
  schema                         = var.snowflake_schema
  format_type                    = "CSV"
  parse_header                   = true
  field_optionally_enclosed_by   = "\""
  skip_blank_lines               = true
  trim_space                     = true
  error_on_column_count_mismatch = false
}

# =============================================================================
# Snowflake Stage
# =============================================================================

resource "snowflake_stage" "this" {
  count               = var.snowflake_enabled ? 1 : 0
  name                = var.snowflake_stage_name
  database            = var.snowflake_database
  schema              = var.snowflake_schema
  url                 = "s3://${var.bucket_name}/"
  storage_integration = snowflake_storage_integration.this[0].name
  file_format         = "FORMAT_NAME = \"${var.snowflake_database}\".\"${var.snowflake_schema}\".\"${var.snowflake_file_format_name}\""  # ← quoted for case sensitivity

  depends_on = [snowflake_file_format.csv]
}
# =============================================================================
# Snowflake Pipe
# =============================================================================

resource "snowflake_pipe" "this" {
  count       = var.snowflake_enabled ? 1 : 0
  name        = var.snowflake_pipe_name
  database    = var.snowflake_database
  schema      = var.snowflake_schema
  auto_ingest = true

  copy_statement = <<-EOF
    COPY INTO "${var.snowflake_database}"."${var.snowflake_schema}"."${var.snowflake_table}"
    FROM @"${var.snowflake_database}"."${var.snowflake_schema}"."${var.snowflake_stage_name}"
    FILE_FORMAT = (FORMAT_NAME = '"${var.snowflake_database}"."${var.snowflake_schema}"."${var.snowflake_file_format_name}"')
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
  EOF

   depends_on = [snowflake_stage.this, terraform_data.snowflake_trust]
}


resource "terraform_data" "snowflake_trust" {
  count = var.snowflake_enabled ? 1 : 0

  triggers_replace = [
    snowflake_storage_integration.this[0].storage_aws_iam_user_arn,
    snowflake_storage_integration.this[0].storage_aws_external_id
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $iam_user_arn = "${snowflake_storage_integration.this[0].storage_aws_iam_user_arn}"
      $external_id = "${snowflake_storage_integration.this[0].storage_aws_external_id}"
      $role_name = "${var.snowflake_iam_role_name}"
      $file = "trust-policy-$role_name.json"

      $policy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"' + $iam_user_arn + '"},"Action":"sts:AssumeRole","Condition":{"StringEquals":{"sts:ExternalId":"' + $external_id + '"}}}]}'
      
      [System.IO.File]::WriteAllText($file, $policy)
      
      aws iam update-assume-role-policy --role-name $role_name --policy-document "file://$file"
      
      Remove-Item $file -Force -ErrorAction SilentlyContinue

      Write-Host "Waiting 15 seconds for IAM policy to propagate..."
      Start-Sleep -Seconds 15  # ← wait for IAM propagation
    EOT
  }

  depends_on = [snowflake_storage_integration.this]
}

# =============================================================================
# Snowflake Stream
# =============================================================================

resource "snowflake_stream_on_table" "pos_unified" {
  count       = var.snowflake_enabled ? 1 : 0
  name        = var.snowflake_stream_name
  database    = var.snowflake_database
  schema      = var.snowflake_schema
  table       = "${var.snowflake_database}.${var.snowflake_schema}.${var.snowflake_table}"
  append_only = true

  depends_on = [snowflake_pipe.this]
}
# =============================================================================
# Snowflake Tasks
# =============================================================================

resource "snowflake_task" "load_pos_backup" {
  count     = var.snowflake_enabled ? 1 : 0
  name      = var.snowflake_backup_task_name
  database  = var.snowflake_database
  schema    = var.snowflake_task_schema
  warehouse = "COMPUTE_WH"
  started   = true

  schedule {
    minutes = 1
  }

  sql_statement = templatefile("${path.root}/../src/Database/snowflake/tasks/load_pos_backup.sql", {
    database      = var.snowflake_database
    schema        = var.snowflake_schema
    stream_name   = var.snowflake_stream_name
    backup_schema = var.snowflake_backup_schema
    dim_schema    = var.snowflake_dim_schema
  })

  depends_on = [snowflake_stream_on_table.pos_unified]
}

resource "snowflake_task" "load_fact_pos" {
  count     = var.snowflake_enabled ? 1 : 0
  name      = var.snowflake_fact_task_name
  database  = var.snowflake_database
  schema    = var.snowflake_task_schema
  warehouse = "COMPUTE_WH"
  started   = true
  after     = ["${var.snowflake_database}.${var.snowflake_task_schema}.${var.snowflake_backup_task_name}"]

  sql_statement = "CALL \"${var.snowflake_database}\".\"${var.snowflake_fact_schema}\".\"load_fact_pos_proc\"()"  # ← replace templatefile with this

  depends_on = [snowflake_task.load_pos_backup]
}