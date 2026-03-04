output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.compute.function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.compute.function_name
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function (used by API Gateway)"
  value       = module.compute.function_invoke_arn
}

output "lambda_alias_arn" {
  description = "ARN of the Lambda alias"
  value       = module.compute.alias_arn
}

output "lambda_function_url" {
  description = "HTTPS Function URL endpoint (if enabled)"
  value       = module.compute.function_url
}

output "lambda_log_group" {
  description = "CloudWatch log group name"
  value       = module.compute.log_group_name
}

output "lambda_iam_role_arn" {
  description = "ARN of the Lambda execution IAM role"
  value       = module.compute.iam_role_arn
}