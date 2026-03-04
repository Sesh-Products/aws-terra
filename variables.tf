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
# Lambda
# =============================================================================

variable "lambda_functions" {
  description = <<-EOT
    Map of Lambda function configurations. Each key is a logical name that becomes
    part of the function name (my-python-lambda-<key>-<environment>).
    All fields are optional and fall back to the stated defaults.
  EOT
  type = map(object({
    runtime                        = optional(string, "python3.12")
    handler                        = optional(string, "index.handler")
    filename                       = optional(string, "./modules/compute/function.zip")
    memory_size                    = optional(number, 256)
    timeout                        = optional(number, 60)
    ephemeral_storage_size         = optional(number, null)
    reserved_concurrent_executions = optional(number, -1)
    architectures                  = optional(list(string), ["arm64"])
    publish                        = optional(bool, true)
    create_alias                   = optional(bool, false)
    log_retention_days             = optional(number, 14)
    log_level                      = optional(string, "INFO")
  }))
  default = {
    api = {
      memory_size = 256
      timeout     = 60
      log_level   = "INFO"
    }
  }
}
