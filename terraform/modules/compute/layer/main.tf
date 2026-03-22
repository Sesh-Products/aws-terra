resource "aws_lambda_layer_version" "this" {
  layer_name   = var.layer_name
  description  = var.description
  license_info = var.license_info

  filename         = var.filename
  source_code_hash = var.source_code_hash

  compatible_runtimes      = var.compatible_runtimes
  compatible_architectures = var.compatible_architectures

  skip_destroy = var.skip_destroy
}
