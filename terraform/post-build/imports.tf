# Domain Identity
import {
  to = module.network.aws_ses_domain_identity.this
  id = "data.seshproducts.com"
}

# DKIM
import {
  to = module.network.aws_ses_domain_dkim.this
  id = "data.seshproducts.com"
}

# Email Identities
import {
  to = module.network.aws_ses_email_identity.this["naimish@seshproducts.com"]
  id = "naimish@seshproducts.com"
}

import {
  to = module.network.aws_ses_email_identity.this["data-ingest@seshproducts.com"]
  id = "data-ingest@seshproducts.com"
}

# Receipt Rule Set
import {
  to = module.network.aws_ses_receipt_rule_set.this
  id = "pos_extract_trigger_dev"
}

# Active Receipt Rule Set
import {
  to = module.network.aws_ses_active_receipt_rule_set.this
  id = "pos_extract_trigger_dev"
}

# Receipt Rule — format: rule_set_name:rule_name
import {
  to = module.network.aws_ses_receipt_rule.this
  id = "pos_extract_trigger_dev:pos_extract_trigger_dev"
}
