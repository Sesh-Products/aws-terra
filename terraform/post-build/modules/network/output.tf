# ===========================================================================
# SES Outputs
# ===========================================================================

output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.this.arn
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for DNS configuration"
  value       = aws_ses_domain_dkim.this.dkim_tokens
}

output "ses_rule_set_name" {
  description = "Name of the active SES receipt rule set"
  value       = aws_ses_receipt_rule_set.this.rule_set_name
}

output "ses_email_identity_arns" {
  description = "ARNs of verified SES email identities"
  value       = { for k, v in aws_ses_email_identity.this : k => v.arn }
}
