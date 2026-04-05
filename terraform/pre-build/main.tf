
# =============================================================================
# Secrets Manager
# =============================================================================

module "secrets" {
  for_each = var.secrets
  source   = "./modules/secrets"

  secret_name             = each.value.secret_name
  description             = each.value.description
  kms_key_id              = each.value.kms_key_id
  recovery_window_in_days = each.value.recovery_window_in_days
  secret_policy           = each.value.secret_policy
  rotation_lambda_arn     = each.value.rotation_lambda_arn
  rotation_days           = each.value.rotation_days

  secret_string = (
    each.key == "snowflake_private_key" ? (
      var.snowflake_private_key != null ? var.snowflake_private_key : each.value.secret_string
    ) :
    each.value.secret_string
  )

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}
