# =============================================================================
# Bucket
# =============================================================================

output "bucket_id" {
  description = "Name (ID) of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name in the format <bucket>.s3.amazonaws.com"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Region-specific domain name in the format <bucket>.s3.<region>.amazonaws.com"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the bucket's region. Used for alias records."
  value       = aws_s3_bucket.this.hosted_zone_id
}

output "bucket_region" {
  description = "AWS region the bucket was created in"
  value       = aws_s3_bucket.this.region
}

# =============================================================================
# Website
# =============================================================================

output "website_endpoint" {
  description = "S3 static website endpoint. null when website hosting is not enabled."
  value       = var.website_config != null ? aws_s3_bucket_website_configuration.this[0].website_endpoint : null
}

output "website_domain" {
  description = "Domain of the S3 static website. Used for Route 53 alias targets. null when not enabled."
  value       = var.website_config != null ? aws_s3_bucket_website_configuration.this[0].website_domain : null
}

# =============================================================================
# Versioning
# =============================================================================

output "versioning_status" {
  description = "Current versioning state of the bucket"
  value       = aws_s3_bucket_versioning.this.versioning_configuration[0].status
}

# =============================================================================
# Encryption
# =============================================================================

output "sse_algorithm" {
  description = "Server-side encryption algorithm applied to the bucket"
  value       = aws_s3_bucket_server_side_encryption_configuration.this.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm
}
