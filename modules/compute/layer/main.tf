# =============================================================================
# Custom Layer — your own zip (use_ssm_layer = false)
# =============================================================================
resource "aws_lambda_layer_version" "this" {
  count = var.use_ssm_layer ? 0 : 1

  layer_name               = var.layer_name
  description              = var.description
  license_info             = var.license_info
  filename                 = var.filename != null ? var.filename : null
  source_code_hash         = var.source_code_hash
  compatible_runtimes      = var.compatible_runtimes
  compatible_architectures = var.compatible_architectures
  skip_destroy             = var.skip_destroy
}

# =============================================================================
# AWS Managed Layer via SSM — pandas (use_ssm_layer = true)
# =============================================================================
data "aws_ssm_parameter" "this" {
  count = var.use_ssm_layer ? 1 : 0
  name  = "/aws/service/aws-sdk-pandas/${var.pandas_version}/${var.python_version}/${var.architecture}/layer-arn"
}