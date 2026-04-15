# ===========================================================================
# SES — Domain Identity
# ===========================================================================

resource "aws_ses_domain_identity" "this" {
  domain = var.ses_domain
}

# ===========================================================================
# SES — Email Identities
# ===========================================================================

resource "aws_ses_email_identity" "this" {
  for_each = toset(var.ses_email_identities)
  email    = each.value
}

# ===========================================================================
# SES — DKIM
# ===========================================================================

resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}

# ===========================================================================
# SES — Receipt Rule Set
# ===========================================================================

resource "aws_ses_receipt_rule_set" "this" {
  rule_set_name = var.ses_rule_set_name
}

resource "aws_ses_active_receipt_rule_set" "this" {
  rule_set_name = aws_ses_receipt_rule_set.this.rule_set_name
}

# ===========================================================================
# SES — Receipt Rule
# ===========================================================================

resource "aws_ses_receipt_rule" "this" {
  name          = var.ses_rule_name
  rule_set_name = aws_ses_receipt_rule_set.this.rule_set_name
  enabled       = true
  tls_policy    = "Optional"
  scan_enabled  = true

  recipients = var.ses_rule_recipients

  s3_action {
    bucket_name       = var.ses_s3_bucket_name
    object_key_prefix = var.ses_s3_key_prefix
    position          = 1
  }

  lambda_action {
    function_arn    = var.ses_lambda_function_arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [aws_ses_receipt_rule_set.this]
}
