# =============================================================================
# General
# =============================================================================

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Instance
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.nano"
}

variable "ami_id" {
  description = "AMI ID. Leave null to use latest Amazon Linux 2023 ARM64"
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "Associate a public IP address with the instance"
  type        = bool
  default     = true
}

# =============================================================================
# Script & Environment
# =============================================================================

variable "script_source_dir" {
  description = "Local path to the directory containing the Python scripts"
  type        = string
  default     = null
}

variable "s3_script_bucket" {
  description = "S3 bucket to stage scripts for EC2 to download"
  type        = string
}

variable "s3_script_prefix" {
  description = "S3 key prefix for staged scripts"
  type        = string
  default     = "ec2-scripts"
}

variable "environment_variables" {
  description = "Environment variables to inject into the instance"
  type        = map(string)
  default     = {}
}

# =============================================================================
# IAM
# =============================================================================

variable "additional_policy_statements" {
  description = "Additional IAM policy statements for the EC2 role"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

# =============================================================================
# packages
# =============================================================================

variable "packages" {
  description = "System packages to install via dnf"
  type        = list(string)
  default     = []
}

variable "pip_packages" {
  description = "Python packages to install via pip"
  type        = list(string)
  default     = []
}

variable "install_playwright" {
  description = "Install Playwright and Chromium browser"
  type        = bool
  default     = false
}

variable "startup_script" {
  description = "Additional bash commands to run at startup"
  type        = string
  default     = ""
}