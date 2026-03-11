# Storage Module — AWS S3

Provisions an S3 bucket with ownership controls, public access block, versioning, encryption, lifecycle rules, logging, CORS, website hosting, bucket policy, event notifications, transfer acceleration, and intelligent tiering.

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  bucket_name       = "my-app-dev-data"
  versioning_status = "Enabled"
  sse_algorithm     = "AES256"

  lifecycle_rules = [
    {
      id     = "cleanup-tmp"
      filter = { prefix = "tmp/" }
      expiration = { days = 30 }
      abort_incomplete_multipart_upload = { days_after_initiation = 7 }
    }
  ]

  tags = { Environment = "dev" }
}
```

## Key Variables

| Variable | Default | Description |
|---|---|---|
| `bucket_name` | **required** | Globally unique bucket name |
| `force_destroy` | `false` | Delete all objects on destroy |
| `versioning_status` | `Disabled` | `Enabled`, `Suspended`, or `Disabled` |
| `sse_algorithm` | `AES256` | `AES256` (SSE-S3) or `aws:kms` (SSE-KMS) |
| `kms_master_key_id` | `null` | KMS key ARN for SSE-KMS |
| `bucket_key_enabled` | `false` | Reduce KMS API calls (SSE-KMS only) |
| `block_public_acls` | `true` | Block public ACLs |
| `block_public_policy` | `true` | Block public bucket policies |
| `lifecycle_rules` | `[]` | List of lifecycle rules (expiration, transitions) |
| `logging_target_bucket` | `null` | Bucket to receive access logs |
| `cors_rules` | `[]` | List of CORS rules |
| `website_config` | `null` | Static website hosting config |
| `bucket_policy` | `null` | JSON IAM policy to attach |
| `notification_configuration` | `null` | Event notifications to Lambda, SQS, or SNS |
| `acceleration_status` | `null` | `Enabled` or `Suspended` |
| `intelligent_tiering_configurations` | `[]` | Intelligent-Tiering archive configs |

## Outputs

| Output | Description |
|---|---|
| `bucket_id` | Bucket name |
| `bucket_arn` | Bucket ARN |
| `bucket_regional_domain_name` | Region-specific domain name |
| `bucket_region` | AWS region |
| `website_endpoint` | Static website endpoint (`null` if not enabled) |
| `versioning_status` | Current versioning state |
| `sse_algorithm` | Encryption algorithm in use |

## Files

```
modules/storage/
├── main.tf        # Resources
├── variables.tf   # Inputs
└── output.tf      # Outputs
```
