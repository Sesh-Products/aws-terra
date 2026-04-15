# ===========================================================================
# SES Variables
# ===========================================================================

variable "environment" {
  description = "Deployment environment name"
  type        = string
}

variable "project" {
  description = "Project name applied as a tag to all resources"
  type        = string
}

variable "ses_domain" {
  description = "Domain to verify in SES"
  type        = string
}

variable "ses_email_identities" {
  description = "List of email addresses to verify in SES"
  type        = list(string)
  default     = []
}

variable "ses_rule_set_name" {
  description = "Name of the SES receipt rule set"
  type        = string
}

variable "ses_rule_name" {
  description = "Name of the SES receipt rule"
  type        = string
}

variable "ses_rule_recipients" {
  description = "List of recipient domains or emails for the receipt rule"
  type        = list(string)
}

variable "ses_s3_bucket_name" {
  description = "S3 bucket where SES stores raw incoming emails"
  type        = string
}

variable "ses_s3_key_prefix" {
  description = "S3 object key prefix for stored SES emails"
  type        = string
  default     = "ses-emails/"
}

variable "ses_lambda_function_arn" {
  description = "ARN of the Lambda function triggered by the SES receipt rule"
  type        = string
}
