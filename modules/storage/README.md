# Storage Module — AWS S3

Terraform module that provisions an AWS S3 bucket with every available configuration option, including ownership controls, public access block, versioning, server-side encryption, lifecycle rules, logging, CORS, static website hosting, bucket policy, event notifications, transfer acceleration, request payment, and intelligent tiering.

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  bucket_name   = "my-app-dev-data"
  force_destroy = true

  versioning_status = "Enabled"
  sse_algorithm     = "AES256"

  lifecycle_rules = [
    {
      id = "cleanup-tmp"
      filter = { prefix = "tmp/" }
      expiration = { days = 30 }
      abort_incomplete_multipart_upload = { days_after_initiation = 7 }
    }
  ]

  tags = {
    Environment = "dev"
    Project     = "aws-terra"
  }
}
```

To deploy with dev values:

```bash
terraform init
terraform plan -var-file="modules/storage/dev.tfvars"
terraform apply -var-file="modules/storage/dev.tfvars"
```

---

## Resources Created

| Resource | Description |
|---|---|
| `aws_s3_bucket` | The S3 bucket |
| `aws_s3_bucket_ownership_controls` | Object ownership rule (always created) |
| `aws_s3_bucket_public_access_block` | Public access restrictions (always created) |
| `aws_s3_bucket_versioning` | Versioning configuration (always created) |
| `aws_s3_bucket_server_side_encryption_configuration` | SSE encryption rule (always created) |
| `aws_s3_bucket_lifecycle_configuration` | Lifecycle rules (when `lifecycle_rules` is non-empty) |
| `aws_s3_bucket_logging` | Server access logging (when `logging_target_bucket` is set) |
| `aws_s3_bucket_cors_configuration` | CORS rules (when `cors_rules` is non-empty) |
| `aws_s3_bucket_website_configuration` | Static website hosting (when `website_config` is set) |
| `aws_s3_bucket_policy` | Bucket IAM policy (when `bucket_policy` is set) |
| `aws_s3_bucket_notification` | Event notifications to Lambda, SQS, or SNS (when `notification_configuration` is set) |
| `aws_s3_bucket_accelerate_configuration` | Transfer acceleration (when `acceleration_status` is set) |
| `aws_s3_bucket_request_payment_configuration` | Request payment config (when `request_payer` is set) |
| `aws_s3_bucket_intelligent_tiering_configuration` | Intelligent tiering archive configs (one per entry in `intelligent_tiering_configurations`) |

---

## Settings Reference

### General

| Variable | Type | Default | Description |
|---|---|---|---|
| `bucket_name` | `string` | **required** | Globally unique name for the S3 bucket |
| `force_destroy` | `bool` | `false` | Delete all objects on destroy so the bucket can be removed without error |
| `object_lock_enabled` | `bool` | `false` | Enable Object Lock. Cannot be disabled after bucket creation |
| `tags` | `map(string)` | `{}` | Tags applied to all resources in this module |

### Ownership Controls

| Variable | Type | Default | Description |
|---|---|---|---|
| `object_ownership` | `string` | `"BucketOwnerEnforced"` | `BucketOwnerEnforced` disables ACLs (recommended). `BucketOwnerPreferred` or `ObjectWriter` enable ACLs |

### Public Access Block

| Variable | Type | Default | Description |
|---|---|---|---|
| `block_public_acls` | `bool` | `true` | Block public access granted through ACLs |
| `block_public_policy` | `bool` | `true` | Block public access granted through bucket policies |
| `ignore_public_acls` | `bool` | `true` | Ignore all public ACLs on the bucket and objects |
| `restrict_public_buckets` | `bool` | `true` | Restrict public bucket policies to authorised AWS service principals only |

### Versioning

| Variable | Type | Default | Description |
|---|---|---|---|
| `versioning_status` | `string` | `"Disabled"` | `Enabled` = keep all versions. `Suspended` = stop creating new versions |
| `mfa_delete` | `string` | `"Disabled"` | Require MFA for version deletion. Only valid when `versioning_status = Enabled` |

### Encryption

| Variable | Type | Default | Description |
|---|---|---|---|
| `sse_algorithm` | `string` | `"AES256"` | `AES256` = SSE-S3 (free). `aws:kms` = SSE-KMS (uses KMS key) |
| `kms_master_key_id` | `string` | `null` | ARN or ID of the KMS key. Defaults to the AWS managed `aws/s3` key when `sse_algorithm = aws:kms` |
| `bucket_key_enabled` | `bool` | `false` | Reduce KMS API calls and cost with an S3 Bucket Key. Only applicable when `sse_algorithm = aws:kms` |

### Lifecycle Rules

| Variable | Type | Default | Description |
|---|---|---|---|
| `lifecycle_rules` | `list(object)` | `[]` | List of lifecycle rules. Each rule can define expiration, transitions, noncurrent version management, and multipart upload cleanup |
| `lifecycle_rules[*].id` | `string` | **required** | Unique ID for the rule |
| `lifecycle_rules[*].enabled` | `bool` | `true` | Whether the rule is active |
| `lifecycle_rules[*].filter.prefix` | `string` | `null` | Limit the rule to objects with this key prefix |
| `lifecycle_rules[*].filter.tags` | `map(string)` | `null` | Limit the rule to objects with these tags |
| `lifecycle_rules[*].expiration.days` | `number` | `null` | Delete current version objects after this many days |
| `lifecycle_rules[*].expiration.expired_object_delete_marker` | `bool` | `null` | Remove expired delete markers |
| `lifecycle_rules[*].noncurrent_version_expiration.noncurrent_days` | `number` | `null` | Delete noncurrent versions after this many days |
| `lifecycle_rules[*].abort_incomplete_multipart_upload.days_after_initiation` | `number` | `null` | Abort incomplete multipart uploads after this many days |
| `lifecycle_rules[*].transitions` | `list(object)` | `[]` | Move objects to a different storage class after a number of days |
| `lifecycle_rules[*].transitions[*].days` | `number` | `null` | Days before transitioning |
| `lifecycle_rules[*].transitions[*].storage_class` | `string` | **required** | Target storage class (e.g. `STANDARD_IA`, `GLACIER`, `DEEP_ARCHIVE`) |
| `lifecycle_rules[*].noncurrent_version_transitions` | `list(object)` | `[]` | Transition noncurrent versions to a different storage class |
| `lifecycle_rules[*].noncurrent_version_transitions[*].noncurrent_days` | `number` | **required** | Days before transitioning noncurrent versions |
| `lifecycle_rules[*].noncurrent_version_transitions[*].storage_class` | `string` | **required** | Target storage class |

### Logging

| Variable | Type | Default | Description |
|---|---|---|---|
| `logging_target_bucket` | `string` | `null` | Name of the bucket to receive server access logs. Omit to disable logging |
| `logging_target_prefix` | `string` | `null` | Prefix for log object keys. Defaults to `<bucket_name>/` |

### CORS

| Variable | Type | Default | Description |
|---|---|---|---|
| `cors_rules` | `list(object)` | `[]` | List of CORS rules. Required for browser-based or cross-origin access |
| `cors_rules[*].allowed_methods` | `list(string)` | **required** | HTTP methods to allow (e.g. `GET`, `PUT`, `POST`) |
| `cors_rules[*].allowed_origins` | `list(string)` | **required** | Origins to allow (e.g. `https://example.com` or `*`) |
| `cors_rules[*].allowed_headers` | `list(string)` | `[]` | Request headers to allow |
| `cors_rules[*].expose_headers` | `list(string)` | `[]` | Response headers to expose to the browser |
| `cors_rules[*].max_age_seconds` | `number` | `null` | How long (seconds) browsers can cache the preflight response |

### Website Hosting

| Variable | Type | Default | Description |
|---|---|---|---|
| `website_config` | `object` | `null` | Enable static website hosting. Set to expose an S3 website endpoint |
| `website_config.index_document` | `string` | **required** | Key of the index document (e.g. `index.html`) |
| `website_config.error_document` | `string` | `null` | Key of the custom error document (e.g. `error.html`) |
| `website_config.redirect_all_requests_to` | `string` | `null` | Redirect all requests to this hostname. When set, `index_document` is ignored |

### Bucket Policy

| Variable | Type | Default | Description |
|---|---|---|---|
| `bucket_policy` | `string` | `null` | JSON IAM policy document to attach to the bucket. Use `jsonencode()` or a `data.aws_iam_policy_document` source |

### Notifications

| Variable | Type | Default | Description |
|---|---|---|---|
| `notification_configuration` | `object` | `null` | S3 event notification targets. Omit to disable all notifications |
| `notification_configuration.lambda_functions` | `list(object)` | `[]` | Lambda functions to invoke on bucket events |
| `notification_configuration.lambda_functions[*].id` | `string` | **required** | Unique ID for this notification |
| `notification_configuration.lambda_functions[*].lambda_arn` | `string` | **required** | ARN of the Lambda function to invoke |
| `notification_configuration.lambda_functions[*].events` | `list(string)` | **required** | S3 events to trigger on (e.g. `s3:ObjectCreated:*`) |
| `notification_configuration.lambda_functions[*].filter_prefix` | `string` | `null` | Only trigger for object keys with this prefix |
| `notification_configuration.lambda_functions[*].filter_suffix` | `string` | `null` | Only trigger for object keys with this suffix |
| `notification_configuration.queues` | `list(object)` | `[]` | SQS queues to notify on bucket events (same fields as `lambda_functions`, with `queue_arn`) |
| `notification_configuration.topics` | `list(object)` | `[]` | SNS topics to notify on bucket events (same fields as `lambda_functions`, with `topic_arn`) |

### Transfer Acceleration

| Variable | Type | Default | Description |
|---|---|---|---|
| `acceleration_status` | `string` | `null` | `Enabled` = route uploads through CloudFront edge locations. `Suspended` = disable. Omit to skip |

### Request Payment

| Variable | Type | Default | Description |
|---|---|---|---|
| `request_payer` | `string` | `null` | `BucketOwner` = owner pays. `Requester` = requester-pays model. Omit to skip |

### Intelligent Tiering

| Variable | Type | Default | Description |
|---|---|---|---|
| `intelligent_tiering_configurations` | `list(object)` | `[]` | List of Intelligent-Tiering archive configurations |
| `intelligent_tiering_configurations[*].name` | `string` | **required** | Unique name for this configuration |
| `intelligent_tiering_configurations[*].status` | `string` | `"Enabled"` | `Enabled` or `Disabled` |
| `intelligent_tiering_configurations[*].filter.prefix` | `string` | `null` | Limit to objects with this key prefix |
| `intelligent_tiering_configurations[*].filter.tags` | `map(string)` | `null` | Limit to objects with these tags |
| `intelligent_tiering_configurations[*].archive_access_days` | `number` | `null` | Days of no access before moving to Archive Access tier (min 90) |
| `intelligent_tiering_configurations[*].deep_archive_access_days` | `number` | `null` | Days before moving to Deep Archive Access tier (min 180) |

---

## Outputs

| Output | Description |
|---|---|
| `bucket_id` | Name (ID) of the S3 bucket |
| `bucket_arn` | ARN of the S3 bucket |
| `bucket_domain_name` | Domain name in the format `<bucket>.s3.amazonaws.com` |
| `bucket_regional_domain_name` | Region-specific domain `<bucket>.s3.<region>.amazonaws.com` |
| `bucket_hosted_zone_id` | Route 53 hosted zone ID for the bucket's region |
| `bucket_region` | AWS region the bucket was created in |
| `website_endpoint` | S3 static website endpoint (`null` if not enabled) |
| `website_domain` | Domain for Route 53 alias records (`null` if not enabled) |
| `versioning_status` | Current versioning state of the bucket |
| `sse_algorithm` | Server-side encryption algorithm in use |

---

## File Structure

```
modules/storage/
├── variables.tf   # All input variable declarations
├── main.tf        # All resource definitions
├── output.tf      # All output values
└── dev.tfvars     # Example values for a development environment
```
