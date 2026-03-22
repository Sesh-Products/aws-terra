locals {
  #S.K. Expecting role name to the same as lambda function name with a suffix '-role'
  role_name      = coalesce(var.iam_role_name, "${var.function_name}-role")
  role_arn       = var.create_iam_role ? aws_iam_role.lambda[0].arn : var.iam_role_arn
  log_group_name = "/aws/lambda/${var.function_name}"

  #S.K. Lambda deployment can either be direct or via s3
  filename          = var.local_zip_deployment ? var.filename : null
  source_code_hash  = var.local_zip_deployment ? var.source_code_hash : null
  s3_bucket         = var.local_zip_deployment ? null : var.s3_bucket
  s3_key            = var.local_zip_deployment ? null : var.s3_key
  s3_object_version = var.local_zip_deployment ? null : var.s3_object_version
}

# =============================================================================
# IAM — Execution Role
# =============================================================================

#S.K. Create a role if one doesnt already exist
data "aws_iam_policy_document" "assume_role" {
  count = var.create_iam_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  count = var.create_iam_role ? 1 : 0

  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json

  tags = var.tags
}

#S.K. Always attach cloudWatch write access
resource "aws_iam_role_policy_attachment" "basic_execution" {
  count = var.create_iam_role ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Required when vpc_config is set
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count = var.create_iam_role && var.attach_vpc_policy ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


# =============================================================================
# CloudWatch Log Group
# =============================================================================

resource "aws_cloudwatch_log_group" "lambda" {
  name              = local.log_group_name
  retention_in_days = var.cloudwatch_log_group_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# =============================================================================
# Lambda Function
# =============================================================================

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = local.role_arn

  # ---- Code source (driven by local_zip_deployment flag) --------------------
  filename          = local.filename
  source_code_hash  = local.source_code_hash
  s3_bucket         = local.s3_bucket
  s3_key            = local.s3_key
  s3_object_version = local.s3_object_version
  package_type      = var.package_type

  # ---- Runtime ---------------------------------------------------------------
  handler       = var.handler
  runtime       = var.runtime
  architectures = var.architectures

  # ---- Performance -----------------------------------------------------------
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # ---- Ephemeral storage (/tmp) ----------------------------------------------
  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size != null ? [var.ephemeral_storage_size] : []
    content {
      size = ephemeral_storage.value
    }
  }

  # ---- Versioning ------------------------------------------------------------
  publish      = var.publish
  skip_destroy = var.skip_destroy

  # ---- Encryption ------------------------------------------------------------
  kms_key_arn = var.kms_key_arn

  # ---- VPC -------------------------------------------------------------------
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids                  = vpc_config.value.subnet_ids
      security_group_ids          = vpc_config.value.security_group_ids
      ipv6_allowed_for_dual_stack = vpc_config.value.ipv6_allowed_for_dual_stack
    }
  }

  replace_security_groups_on_destroy = var.replace_security_groups_on_destroy
  replacement_security_group_ids     = var.replacement_security_group_ids

  # ---- Environment variables -------------------------------------------------
  dynamic "environment" {
    for_each = var.environment_variables != null ? [var.environment_variables] : []
    content {
      variables = environment.value
    }
  }

  # ---- Dead letter queue -----------------------------------------------------
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [var.dead_letter_target_arn] : []
    content {
      target_arn = dead_letter_config.value
    }
  }

  # ---- EFS -------------------------------------------------------------------
  dynamic "file_system_config" {
    for_each = var.file_system_config != null ? [var.file_system_config] : []
    content {
      arn              = file_system_config.value.arn
      local_mount_path = file_system_config.value.local_mount_path
    }
  }

  # ---- Layers ----------------------------------------------------------------
  layers = length(var.layer_arns) > 0 ? var.layer_arns : null

  # ---- Advanced logging ------------------------------------------------------
  dynamic "logging_config" {
    for_each = var.logging_config != null ? [var.logging_config] : []
    content {
      log_format            = logging_config.value.log_format
      log_group             = coalesce(logging_config.value.log_group, local.log_group_name)
      application_log_level = logging_config.value.application_log_level
      system_log_level      = logging_config.value.system_log_level
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.basic_execution,
    aws_cloudwatch_log_group.lambda,
  ]
}

# =============================================================================
# Lambda Alias
# =============================================================================

resource "aws_lambda_alias" "this" {
  count = var.create_alias ? 1 : 0

  name             = var.alias_name
  description      = var.alias_description
  function_name    = aws_lambda_function.this.function_name
  function_version = var.publish ? aws_lambda_function.this.version : "$LATEST"

  dynamic "routing_config" {
    for_each = var.alias_routing_config != null ? [var.alias_routing_config] : []
    content {
      additional_version_weights = routing_config.value
    }
  }
}

# =============================================================================
# Provisioned Concurrency
# =============================================================================

resource "aws_lambda_provisioned_concurrency_config" "this" {
  count = var.provisioned_concurrent_executions > 0 && var.publish ? 1 : 0

  function_name                      = aws_lambda_function.this.function_name
  qualifier                          = aws_lambda_function.this.version
  provisioned_concurrent_executions  = var.provisioned_concurrent_executions
}

# =============================================================================
# Function URL
# =============================================================================

resource "aws_lambda_function_url" "this" {
  count = var.create_function_url ? 1 : 0

  function_name      = aws_lambda_function.this.function_name
  qualifier          = var.create_alias ? aws_lambda_alias.this[0].name : null
  authorization_type = var.function_url_authorization_type
  invoke_mode        = var.function_url_invoke_mode

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    content {
      allow_credentials = cors.value.allow_credentials
      allow_headers     = cors.value.allow_headers
      allow_methods     = cors.value.allow_methods
      allow_origins     = cors.value.allow_origins
      expose_headers    = cors.value.expose_headers
      max_age           = cors.value.max_age
    }
  }
}

# =============================================================================
# Async Invocation Config
# =============================================================================

resource "aws_lambda_function_event_invoke_config" "this" {
  count = (
    var.maximum_event_age_in_seconds != null ||
    var.maximum_retry_attempts != null ||
    var.destination_on_success_arn != null ||
    var.destination_on_failure_arn != null
  ) ? 1 : 0

  function_name                = aws_lambda_function.this.function_name
  qualifier                    = var.create_alias ? aws_lambda_alias.this[0].name : null
  maximum_event_age_in_seconds = var.maximum_event_age_in_seconds
  maximum_retry_attempts       = var.maximum_retry_attempts

  dynamic "destination_config" {
    for_each = (var.destination_on_success_arn != null || var.destination_on_failure_arn != null) ? [1] : []
    content {
      dynamic "on_success" {
        for_each = var.destination_on_success_arn != null ? [var.destination_on_success_arn] : []
        content {
          destination = on_success.value
        }
      }
      dynamic "on_failure" {
        for_each = var.destination_on_failure_arn != null ? [var.destination_on_failure_arn] : []
        content {
          destination = on_failure.value
        }
      }
    }
  }
}

# =============================================================================
# Lambda Permissions (Trigger sources)
# =============================================================================

resource "aws_lambda_permission" "this" {
  for_each = var.allowed_triggers

  statement_id   = coalesce(each.value.statement_id, "Allow${each.key}")
  action         = each.value.action
  function_name  = aws_lambda_function.this.function_name
  principal      = each.value.principal
  source_arn     = each.value.source_arn
  source_account = each.value.source_account
  qualifier      = coalesce(each.value.qualifier, var.create_alias ? aws_lambda_alias.this[0].name : null)
}

# =============================================================================
# Additional IAM Role Policy
# =============================================================================

resource "aws_iam_role_policy" "additional" {
  count = length(var.additional_policy_statements) > 0 ? 1 : 0

  name = "${local.role_name}-additional-policy"
  role = aws_iam_role.lambda[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for stmt in var.additional_policy_statements : {
        Effect   = stmt.effect
        Action   = stmt.actions
        Resource = stmt.resources
      }
    ]
  })
}