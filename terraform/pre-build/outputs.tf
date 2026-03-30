output "secret_arns" {
  description = "ARN of each Secrets Manager secret"
  value       = { for k, v in module.secrets : k => v.secret_arn }
}