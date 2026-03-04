# =============================================================================
# Lambda Function
# =============================================================================

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_invoke_arn" {
  description = "Invoke ARN used to call this function from API Gateway or Step Functions"
  value       = aws_lambda_function.this.invoke_arn
}

output "function_qualified_arn" {
  description = "Qualified ARN including the version number (e.g. arn:aws:lambda:...:function:name:3)"
  value       = aws_lambda_function.this.qualified_arn
}

output "function_version" {
  description = "Latest published version number. Only populated when publish = true."
  value       = aws_lambda_function.this.version
}

output "function_last_modified" {
  description = "Timestamp of the last deployment"
  value       = aws_lambda_function.this.last_modified
}

output "function_source_code_hash" {
  description = "Base64-encoded SHA256 hash of the current deployment package"
  value       = aws_lambda_function.this.source_code_hash
}

output "function_source_code_size" {
  description = "Size in bytes of the deployment package"
  value       = aws_lambda_function.this.source_code_size
}

# =============================================================================
# IAM Role
# =============================================================================

output "iam_role_arn" {
  description = "ARN of the Lambda execution IAM role"
  value       = var.create_iam_role ? aws_iam_role.lambda[0].arn : var.iam_role_arn
}

output "iam_role_name" {
  description = "Name of the Lambda execution IAM role"
  value       = var.create_iam_role ? aws_iam_role.lambda[0].name : null
}

# =============================================================================
# CloudWatch Logs
# =============================================================================

output "log_group_name" {
  description = "Name of the CloudWatch log group for this function"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

# =============================================================================
# Alias
# =============================================================================

output "alias_arn" {
  description = "ARN of the Lambda alias. null when create_alias = false."
  value       = var.create_alias ? aws_lambda_alias.this[0].arn : null
}

output "alias_invoke_arn" {
  description = "Invoke ARN of the Lambda alias (use this in API Gateway integrations when aliasing)."
  value       = var.create_alias ? aws_lambda_alias.this[0].invoke_arn : null
}

output "alias_name" {
  description = "Name of the Lambda alias"
  value       = var.create_alias ? aws_lambda_alias.this[0].name : null
}

# =============================================================================
# Function URL
# =============================================================================

output "function_url" {
  description = "HTTPS endpoint for the Lambda Function URL. null when create_function_url = false."
  value       = var.create_function_url ? aws_lambda_function_url.this[0].function_url : null
}

output "function_url_id" {
  description = "Unique ID of the Lambda Function URL"
  value       = var.create_function_url ? aws_lambda_function_url.this[0].url_id : null
}