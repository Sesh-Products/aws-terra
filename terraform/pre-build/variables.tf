variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name applied as a tag to all resources"
  type        = string
  default     = "aws-terra"
  
}

# =============================================================================
# Secrets Manager
# =============================================================================

variable "secrets" {
  description = <<-EOT
    Map of Secrets Manager secrets to create. Each key is a logical name.
    secret_string is sensitive — pass via tfvars or environment variable, never hardcode.
  EOT
  type = map(object({
    secret_name             = string
    description             = optional(string, "")
    kms_key_id              = optional(string, null)
    secret_string           = optional(string, null)
    recovery_window_in_days = optional(number, 30)
    secret_policy           = optional(string, null)
    rotation_lambda_arn     = optional(string, null)
    rotation_days           = optional(number, 30)
  }))
  default = {}
}

variable "snowflake_private_key" {
  description = "RSA private key content for Snowflake"
  type        = string
  sensitive   = true
  default     = null
}
