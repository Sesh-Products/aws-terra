# =============================================================================
# General
# =============================================================================

variable "secret_name" {
  description = "Friendly name of the secret. Slashes are allowed (e.g. prod/db/password)."
  type        = string
}

variable "description" {
  description = "Human-readable description of the secret."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}

# =============================================================================
# Encryption
# =============================================================================

variable "kms_key_id" {
  description = "ARN or ID of the KMS key used to encrypt the secret. Defaults to the AWS managed key for Secrets Manager."
  type        = string
  default     = null
}

# =============================================================================
# Secret Value
# =============================================================================

variable "secret_string" {
  description = "Plaintext or JSON-encoded string to store as the secret value. Omit to create the secret without an initial value."
  type        = string
  default     = null
  sensitive   = true
}

# =============================================================================
# Recovery
# =============================================================================

variable "recovery_window_in_days" {
  description = "Number of days Secrets Manager waits before deleting the secret. Set to 0 to delete immediately (disables recovery window)."
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 (force delete) or between 7 and 30."
  }
}

# =============================================================================
# Resource Policy
# =============================================================================

variable "secret_policy" {
  description = "JSON-encoded IAM resource policy to attach to the secret. Use jsonencode() or a data source."
  type        = string
  default     = null
}

# =============================================================================
# Rotation
# =============================================================================

variable "rotation_lambda_arn" {
  description = "ARN of the Lambda function that rotates the secret. Omit to disable rotation."
  type        = string
  default     = null
}

variable "rotation_days" {
  description = "Number of days between automatic rotations. Only used when rotation_lambda_arn is set."
  type        = number
  default     = 30

  validation {
    condition     = var.rotation_days >= 1 && var.rotation_days <= 365
    error_message = "rotation_days must be between 1 and 365."
  }
}
