# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "data-ingest@seshproducts.com"
resource "aws_ses_email_identity" "data_ingest" {
  email = "data-ingest@seshproducts.com"
}

# __generated__ by Terraform from "data.seshproducts.com"
resource "aws_ses_domain_dkim" "this" {
  domain = "data.seshproducts.com"
}

# __generated__ by Terraform from "data.seshproducts.com"
resource "aws_ses_domain_identity" "this" {
  domain = "data.seshproducts.com"
}

# __generated__ by Terraform from "pos_extract_trigger_dev"
resource "aws_ses_receipt_rule_set" "this" {
  rule_set_name = "pos_extract_trigger_dev"
}

# __generated__ by Terraform from "pos_extract_trigger_dev"
resource "aws_ses_active_receipt_rule_set" "this" {
  rule_set_name = "pos_extract_trigger_dev"
}

# __generated__ by Terraform from "naimish@seshproducts.com"
resource "aws_ses_email_identity" "naimish" {
  email = "naimish@seshproducts.com"
}

# __generated__ by Terraform from "pos_extract_trigger_dev:pos_extract_trigger_dev"
resource "aws_ses_receipt_rule" "this" {
  after         = null
  enabled       = true
  name          = "pos_extract_trigger_dev"
  recipients    = ["data.seshproducts.com"]
  rule_set_name = "pos_extract_trigger_dev"
  scan_enabled  = true
  tls_policy    = "Optional"
  lambda_action {
    function_arn    = "arn:aws:lambda:us-east-1:000605313601:function:pos_extract-dev"
    invocation_type = "Event"
    position        = 2
    topic_arn       = null
  }
  s3_action {
    bucket_name       = "pos-raw-email-bucket"
    iam_role_arn      = null
    kms_key_arn       = null
    object_key_prefix = "ses-emails/"
    position          = 1
    topic_arn         = null
  }
}
