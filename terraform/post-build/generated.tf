# __generated__ by Terraform
# SES resources are only managed when manage_ses = true (dev environment).
# Prod reuses the same SES setup without owning these resources in its state.

resource "aws_ses_domain_identity" "this" {
  for_each = var.manage_ses ? { this = var.ses_domain } : {}
  domain   = each.value
}

resource "aws_ses_domain_dkim" "this" {
  for_each = var.manage_ses ? { this = var.ses_domain } : {}
  domain   = each.value
}

resource "aws_ses_email_identity" "this" {
  for_each = var.manage_ses ? var.ses_email_identities : {}
  email    = each.value
}

resource "aws_ses_receipt_rule_set" "this" {
  for_each      = var.manage_ses ? { this = var.ses_rule_set_name } : {}
  rule_set_name = each.value
}

resource "aws_ses_active_receipt_rule_set" "this" {
  for_each      = var.manage_ses ? { this = var.ses_rule_set_name } : {}
  rule_set_name = each.value
}

resource "aws_ses_receipt_rule" "this" {
  for_each      = var.manage_ses ? { this = var.ses_rule_set_name } : {}
  after         = null
  enabled       = true
  name          = var.ses_rule_name
  recipients    = var.ses_rule_recipients
  rule_set_name = var.ses_rule_set_name
  scan_enabled  = true
  tls_policy    = "Optional"
  lambda_action {
    function_arn    = var.ses_lambda_function_arn
    invocation_type = "Event"
    position        = 2
    topic_arn       = null
  }
  s3_action {
    bucket_name       = var.ses_s3_bucket_name
    iam_role_arn      = null
    kms_key_arn       = null
    object_key_prefix = var.ses_s3_key_prefix
    position          = 1
    topic_arn         = null
  }
}
