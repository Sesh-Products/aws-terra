import {
  for_each = var.manage_ses ? { this = var.ses_domain } : {}
  to       = aws_ses_domain_identity.this[each.key]
  id       = each.value
}

import {
  for_each = var.manage_ses ? { this = var.ses_domain } : {}
  to       = aws_ses_domain_dkim.this[each.key]
  id       = each.value
}

import {
  for_each = var.manage_ses ? var.ses_email_identities : {}
  to       = aws_ses_email_identity.this[each.key]
  id       = each.value
}

import {
  for_each = var.manage_ses ? { this = var.ses_rule_set_name } : {}
  to       = aws_ses_receipt_rule_set.this[each.key]
  id       = each.value
}

import {
  for_each = var.manage_ses ? { this = var.ses_rule_set_name } : {}
  to       = aws_ses_active_receipt_rule_set.this[each.key]
  id       = each.value
}

import {
  for_each = var.manage_ses ? { this = var.ses_rule_set_name } : {}
  to       = aws_ses_receipt_rule.this[each.key]
  id       = "${var.ses_rule_set_name}:${var.ses_rule_name}"
}
