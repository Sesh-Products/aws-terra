# =============================================================================
# Secret
# =============================================================================

output "secret_arn" {
  description = "ARN of the secret"
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_id" {
  description = "ID of the secret (same as ARN)"
  value       = aws_secretsmanager_secret.this.id
}

output "secret_name" {
  description = "Name of the secret"
  value       = aws_secretsmanager_secret.this.name
}

# =============================================================================
# Secret Version
# =============================================================================

output "secret_version_id" {
  description = "Unique ID of the current secret version. null when no initial value was set."
  value       = var.secret_string != null ? aws_secretsmanager_secret_version.this[0].version_id : null
}
