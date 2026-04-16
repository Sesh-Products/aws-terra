output "lambda_layer_arns" {
  description = "ARN of each Lambda layer version"
  value       = { for k, v in module.layer : k => v.layer_arn }
}


output "s3_bucket_ids" {
  description = "ID (name) of each S3 bucket"
  value       = { for k, v in module.storage : k => v.bucket_id }
}

output "s3_bucket_arns" {
  description = "ARN of each S3 bucket"
  value       = { for k, v in module.storage : k => v.bucket_arn }
}

output "lambda_function_arn" {
  description = "ARN of each Lambda function"
  value       = { for k, v in module.compute : k => v.function_arn }
}

output "lambda_function_name" {
  description = "Name of each Lambda function"
  value       = { for k, v in module.compute : k => v.function_name }
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of each Lambda function (used by API Gateway)"
  value       = { for k, v in module.compute : k => v.function_invoke_arn }
}

output "lambda_alias_arn" {
  description = "ARN of each Lambda alias"
  value       = { for k, v in module.compute : k => v.alias_arn }
}

output "lambda_function_url" {
  description = "HTTPS Function URL endpoint for each Lambda (if enabled)"
  value       = { for k, v in module.compute : k => v.function_url }
}

output "lambda_log_group" {
  description = "CloudWatch log group name for each Lambda"
  value       = { for k, v in module.compute : k => v.log_group_name }
}

output "lambda_iam_role_arn" {
  description = "ARN of the Lambda execution IAM role for each function"
  value       = { for k, v in module.compute : k => v.iam_role_arn }
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs"
  value       = { for k, v in module.ec2 : k => v.instance_id }
}

output "elastic_ip" {
  description = "Elastic IP for products.seshproducts.com"
  value       = module.react_app.elastic_ip
}

output "instance_id" {
  description = "React app EC2 instance ID"
  value       = module.react_app.instance_id
}