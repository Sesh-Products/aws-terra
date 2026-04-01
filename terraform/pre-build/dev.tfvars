
# =============================================================================
# Secrets
# =============================================================================
snowflake_private_key_path = "C:\\SESH\\ETL Automation\\snowflake-schema_change\\rsa_key.p8"
secrets = {
  snowflake_credentials = {
    secret_name             = "snowflake/pos-pipeline/dev/credentials"
    description             = "Snowflake credentials for pos-pipeline"
    recovery_window_in_days = 0
    secret_string           = "{\"organization\":\"JNPMQNX\",\"account\":\"VI43165\",\"username\":\"JACKIE\"}"
  }
  snowflake_private_key = {
    secret_name             = "snowflake/pos-pipeline/dev/private-key"
    description             = "Snowflake RSA private key"
    recovery_window_in_days = 0
    secret_string           = null  # ← handled in main.tf via file()
  }
}