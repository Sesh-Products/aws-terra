locals {
  ami_id = coalesce(var.ami_id, data.aws_ami.amazon_linux_arm[0].id)

  env_exports = join("\n", [
    for k, v in var.environment_variables : "echo '${k}=${v}' >> /etc/environment" if v != null
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

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

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
# Security Group (optional — only created when vpc_id is provided)
# =============================================================================

resource "aws_security_group" "this" {
  count       = var.vpc_id != null ? 1 : 0
  name        = "${var.instance_name}-sg"
  description = "Security group for ${var.instance_name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# =============================================================================
# EC2 Instance
# =============================================================================

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = var.associate_public_ip
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.vpc_id != null ? [aws_security_group.this[0].id] : []

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  # S3-based user data — used when s3_user_data_script is set
  # Falls back to inline user data for standard EC2 instances
  user_data = var.s3_user_data_script != null ? base64encode(join("\n", [
    "#!/bin/bash",
    "export DOMAIN='${var.domain}'",
    "export APP_PORT='${var.app_port}'",
    "export APP_NAME='${var.instance_name}'",
    "export ENVIRONMENT='${var.environment}'",
    "export AWS_REGION='${var.aws_region}'",
    "aws s3 cp s3://${var.s3_script_bucket}/${var.s3_user_data_script} /tmp/setup.sh",
    "chmod +x /tmp/setup.sh",
    "bash /tmp/setup.sh"
  ])) : <<-EOF
  #!/bin/bash
  set -e

  dnf install -y python3.12 python3.12-pip amazon-ssm-agent ${local.dnf_packages} ${local.playwright_deps}

  systemctl enable amazon-ssm-agent
  systemctl start amazon-ssm-agent

  ${local.env_exports}
  set -a
  source /etc/environment
  set +a

  python3.12 -m pip install boto3 ${join(" ", var.pip_packages)}

  ${local.playwright_install}

  mkdir -p /home/ec2-user/scripts
  aws s3 sync s3://${var.s3_script_bucket}/${var.s3_script_prefix}/ /home/ec2-user/scripts/
  chown -R ec2-user:ec2-user /home/ec2-user/scripts

  ${var.startup_script}
  EOF

  user_data_replace_on_change = true

  lifecycle {
    ignore_changes        = [ami]
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}

# =============================================================================
# Elastic IP (optional — only created when create_eip is true)
# =============================================================================

resource "aws_eip" "this" {
  count    = var.create_eip ? 1 : 0
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.instance_name}-eip"
  })
}