import {
  to = aws_ses_domain_identity.this
  id = "data.seshproducts.com"
}

import {
  to = aws_ses_domain_dkim.this
  id = "data.seshproducts.com"
}

import {
  to = aws_ses_email_identity.naimish
  id = "naimish@seshproducts.com"
}

import {
  to = aws_ses_email_identity.data_ingest
  id = "data-ingest@seshproducts.com"
}

import {
  to = aws_ses_receipt_rule_set.this
  id = "pos_extract_trigger_dev"
}

import {
  to = aws_ses_active_receipt_rule_set.this
  id = "pos_extract_trigger_dev"
}

import {
  to = aws_ses_receipt_rule.this
  id = "pos_extract_trigger_dev:pos_extract_trigger_dev"
}