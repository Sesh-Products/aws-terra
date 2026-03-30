locals {
  ami_id = coalesce(var.ami_id, data.aws_ami.amazon_linux_arm[0].id)

  env_exports = join("\n", [
    for k, v in var.environment_variables : "echo 'export ${k}=\"${v}\"' >> /etc/environment"
  ])

  dnf_packages = length(var.packages) > 0 ? join(" ", var.packages) : ""

  pip_install = length(var.pip_packages) > 0 ? "python3.12 -m pip install ${join(" ", var.pip_packages)}" : ""

  playwright_install = var.install_playwright ? "python3.12 -m pip install playwright && PLAYWRIGHT_BROWSERS_PATH=/home/ec2-user/.playwright python3.12 -m playwright install chromium && chown -R ec2-user:ec2-user /home/ec2-user/.playwright" : ""

  playwright_deps = var.install_playwright ? "atk cups-libs gtk3 libXcomposite libXdamage libXext libXrandr libgbm libxkbcommon pango alsa-lib nss nspr libdrm mesa-libgbm xorg-x11-fonts-Type1 xorg-x11-fonts-misc" : ""
}

# =============================================================================
# AMI — Latest Amazon Linux 2023 ARM64
# =============================================================================

data "aws_ami" "amazon_linux_arm" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# =============================================================================
# IAM Role
# =============================================================================

resource "aws_iam_role" "ec2" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

# SSM — allows remote triggering without SSH
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 — to download scripts and upload reports
resource "aws_iam_role_policy" "s3" {
  name = "${var.instance_name}-s3-policy"
  role = aws_iam_role.ec2.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.s3_script_bucket}",
        "arn:aws:s3:::${var.s3_script_bucket}/*"
      ]
    }]
  })
}

# Additional custom policy statements
resource "aws_iam_role_policy" "additional" {
  count = length(var.additional_policy_statements) > 0 ? 1 : 0
  name  = "${var.instance_name}-additional-policy"
  role  = aws_iam_role.ec2.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for stmt in var.additional_policy_statements : {
        Effect   = stmt.effect
        Action   = stmt.actions
        Resource = stmt.resources
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.ec2.name
}

# =============================================================================
# EC2 Instance
# =============================================================================

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = var.associate_public_ip

  user_data = <<-EOF
  #!/bin/bash
  set -e

  # Install system packages
  dnf install -y python3.12 python3.12-pip ${local.dnf_packages} ${local.playwright_deps}

  # Set environment variables
  ${local.env_exports}
  source /etc/environment

  # Install pip packages
  ${local.pip_install}

  # Playwright setup
  ${local.playwright_install}

  # Download scripts from S3
  mkdir -p /home/ec2-user/scripts
  aws s3 sync s3://${var.s3_script_bucket}/${var.s3_script_prefix}/ /home/ec2-user/scripts/
  chown -R ec2-user:ec2-user /home/ec2-user/scripts

  # Additional startup commands
  ${var.startup_script}
  EOF


  tags = merge(var.tags, {
    Name = var.instance_name
  })
}