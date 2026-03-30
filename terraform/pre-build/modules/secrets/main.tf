# =============================================================================
# Secrets Manager Secret
# =============================================================================

resource "aws_secretsmanager_secret" "this" {
  name                    = var.secret_name
  description             = var.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

# =============================================================================
# Secret Value
# =============================================================================

resource "aws_secretsmanager_secret_version" "this" {
  count = var.secret_string != null ? 1 : 0

  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_string
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# =============================================================================
# Resource Policy
# =============================================================================

resource "aws_secretsmanager_secret_policy" "this" {
  count = var.secret_policy != null ? 1 : 0

  secret_arn = aws_secretsmanager_secret.this.arn
  policy     = var.secret_policy
}

# =============================================================================
# Rotation
# =============================================================================

resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.rotation_lambda_arn != null ? 1 : 0

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}
