module "compute" {
  for_each = var.lambda_functions
  source   = "./modules/compute"

  function_name = "my-python-lambda-${each.key}-${var.environment}"
  description   = "Python Lambda function - ${each.key} - ${var.environment} environment"
  runtime       = each.value.runtime
  handler       = each.value.handler

  filename         = each.value.filename
  source_code_hash = filebase64sha256(each.value.filename)

  memory_size                    = each.value.memory_size
  timeout                        = each.value.timeout
  ephemeral_storage_size         = each.value.ephemeral_storage_size
  reserved_concurrent_executions = each.value.reserved_concurrent_executions
  architectures                  = each.value.architectures

  publish      = each.value.publish
  create_alias = each.value.create_alias

  cloudwatch_log_group_retention_days = each.value.log_retention_days

  environment_variables = {
    ENVIRONMENT = var.environment
    LOG_LEVEL   = each.value.log_level
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}
