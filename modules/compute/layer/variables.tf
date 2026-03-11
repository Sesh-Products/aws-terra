# =============================================================================
# Mode switch
# =============================================================================
variable "use_ssm_layer" {
  description = "true = fetch AWS managed pandas layer via SSM. false = upload custom zip."
  type        = bool
  default     = false
}


# =============================================================================
# General
# =============================================================================

variable "layer_name" {
  description = "Name for the Lambda layer version"
  type        = string
  default     = "pandas-layer"
}

variable "description" {
  description = "Human-readable description of the layer"
  type        = string
  default     = ""
}

variable "license_info" {
  description = "SPDX license identifier for the layer contents (e.g. MIT, Apache-2.0)"
  type        = string
  default     = null
}

# =============================================================================
# Code Source — local zip only
# =============================================================================

variable "filename" {
  description = "Path to the local .zip file containing the layer contents"
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the zip. Forces a new layer version on change. Use filebase64sha256()."
  type        = string
  default     = null
}

# =============================================================================
# Runtime Compatibility
# =============================================================================

variable "compatible_runtimes" {
  description = "List of Lambda runtimes this layer is compatible with (up to 15). E.g. [\"python3.12\"]."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([for r in var.compatible_runtimes : contains([
      "python3.8", "python3.9", "python3.10", "python3.11", "python3.12",
      "nodejs18.x", "nodejs20.x",
      "java17", "java21",
      "dotnet6", "dotnet8",
      "ruby3.2", "ruby3.3",
      "provided.al2", "provided.al2023"
    ], r)])
    error_message = "Each runtime must be a valid AWS Lambda runtime identifier."
  }
}

variable "compatible_architectures" {
  description = "List of CPU architectures this layer is compatible with. Valid values: x86_64, arm64."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = alltrue([for a in var.compatible_architectures : contains(["x86_64", "arm64"], a)])
    error_message = "Each architecture must be x86_64 or arm64."
  }
}

# =============================================================================
# Retention
# =============================================================================

variable "skip_destroy" {
  description = "When true, Terraform will not delete old layer versions on destroy or re-deploy."
  type        = bool
  default     = false
}

# =============================================================================
# Pandas
# =============================================================================

variable "pandas_version" {
  description = "AWS SDK for pandas version"
  type        = string
  default     = "3.15.1"
}

variable "python_version" {
  description = "Python version string for SSM path e.g. py3.12"
  type        = string
  default     = "py3.12"
}

variable "architecture" {
  description = "Lambda architecture — arm64 or x86_64"
  type        = string
  default     = "arm64"
}
