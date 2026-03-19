# =============================================================================
# Primary output — works for both SSM and custom layer
# =============================================================================
output "layer_arn" {
  description = "Layer ARN — from SSM if use_ssm_layer=true, else from custom zip"
  value       = var.use_ssm_layer ? data.aws_ssm_parameter.this[0].value : aws_lambda_layer_version.this[0].arn
}

# =============================================================================
# Custom layer only outputs — null when use_ssm_layer = true
# =============================================================================
output "layer_version_arn" {
  description = "Full layer version ARN. null for SSM layers."
  value       = var.use_ssm_layer ? null : aws_lambda_layer_version.this[0].arn
}

output "layer_name" {
  description = "Name of the Lambda layer. null for SSM layers."
  value       = var.use_ssm_layer ? null : aws_lambda_layer_version.this[0].layer_name
}

output "version" {
  description = "Version number of this layer. null for SSM layers."
  value       = var.use_ssm_layer ? null : aws_lambda_layer_version.this[0].version
}

output "created_date" {
  description = "Timestamp when this layer version was created. null for SSM layers."
  value       = var.use_ssm_layer ? null : aws_lambda_layer_version.this[0].created_date
}

output "source_code_size" {
  description = "Size of the layer zip in bytes. null for SSM layers."
  value       = var.use_ssm_layer ? null : aws_lambda_layer_version.this[0].source_code_size
}