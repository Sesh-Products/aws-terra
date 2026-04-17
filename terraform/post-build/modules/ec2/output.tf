output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2.arn
}

output "elastic_ip" {
  description = "Elastic IP address (null if create_eip = false)"
  value       = var.create_eip ? aws_eip.this[0].public_ip : null
}

output "security_group_id" {
  description = "Security group ID (null if vpc_id not set)"
  value       = var.vpc_id != null ? aws_security_group.this[0].id : null
}