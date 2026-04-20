# These moved blocks migrate existing dev state from the old single-instance
# resource addresses to the new for_each addresses introduced when manage_ses
# was added. Terraform applies these transparently — no destroy/recreate.

moved {
  from = aws_ses_domain_identity.this
  to   = aws_ses_domain_identity.this["this"]
}

moved {
  from = aws_ses_domain_dkim.this
  to   = aws_ses_domain_dkim.this["this"]
}

moved {
  from = aws_ses_email_identity.naimish
  to   = aws_ses_email_identity.this["naimish"]
}

moved {
  from = aws_ses_email_identity.data_ingest
  to   = aws_ses_email_identity.this["data_ingest"]
}

moved {
  from = aws_ses_receipt_rule_set.this
  to   = aws_ses_receipt_rule_set.this["this"]
}

moved {
  from = aws_ses_active_receipt_rule_set.this
  to   = aws_ses_active_receipt_rule_set.this["this"]
}

moved {
  from = aws_ses_receipt_rule.this
  to   = aws_ses_receipt_rule.this["this"]
}
