output "layer_arn" {
  description = "Full ARN of the layer version, including version number (use this to attach to a function)"
  value       = aws_lambda_layer_version.this.arn
}

output "layer_version_arn" {
  description = "Alias for layer_arn — same value, provided for clarity"
  value       = aws_lambda_layer_version.this.arn
}

output "layer_name" {
  description = "Name of the Lambda layer"
  value       = aws_lambda_layer_version.this.layer_name
}

output "version" {
  description = "Version number of this layer"
  value       = aws_lambda_layer_version.this.version
}

output "created_date" {
  description = "Timestamp when this layer version was created"
  value       = aws_lambda_layer_version.this.created_date
}

output "source_code_size" {
  description = "Size of the layer zip in bytes"
  value       = aws_lambda_layer_version.this.source_code_size
}
