# Compute Module — AWS Lambda

Terraform module that provisions an AWS Lambda function (Python runtime) with every available configuration option, including IAM, CloudWatch Logs, aliases, provisioned concurrency, Function URLs, async invocation, and trigger permissions.

> Container image and Lambda Layers are not supported in this module.

<!-- TODO(Shivani): Add code signing support — good to have. Enforces that only signed deployment packages can be deployed to the function. See: aws_lambda_code_signing_config. -->

## Usage

```hcl
module "compute" {
  source = "./modules/compute"

  function_name = "my-python-lambda"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = "./function.zip"
  source_code_hash = filebase64sha256("./function.zip")

  memory_size = 256
  timeout     = 60

  environment_variables = {
    ENVIRONMENT = "dev"
  }

  tags = {
    Environment = "dev"
    Project     = "aws-terra"
  }
}
```

To deploy with dev values:

```bash
terraform init
terraform plan -var-file="modules/compute/dev.tfvars"
terraform apply -var-file="modules/compute/dev.tfvars"
```

---

## Resources Created

| Resource | Description |
|---|---|
| `aws_iam_role` | Lambda execution role (when `create_iam_role = true`) |
| `aws_iam_role_policy_attachment` | Attaches basic execution and VPC managed policies |
| `aws_iam_role_policy` | Optional custom inline policy |
| `aws_cloudwatch_log_group` | Log group at `/aws/lambda/<function_name>` |
| `aws_lambda_function` | The Lambda function with all settings |
| `aws_lambda_alias` | Named alias (when `create_alias = true`) |
| `aws_lambda_provisioned_concurrency_config` | Warm execution environments (when enabled) |
| `aws_lambda_function_url` | Direct HTTPS endpoint (when `create_function_url = true`) |
| `aws_lambda_function_event_invoke_config` | Async invocation settings (when any async var is set) |
| `aws_lambda_permission` | Per-trigger invoke permissions (from `allowed_triggers`) |

---

## Settings Reference

### General

| Variable | Type | Default | Description |
|---|---|---|---|
| `function_name` | `string` | **required** | Unique name for the Lambda function |
| `description` | `string` | `""` | Human-readable description |
| `tags` | `map(string)` | `{}` | Tags applied to all resources in this module |

### Runtime & Code Source

| Variable | Type | Default | Description |
|---|---|---|---|
| `runtime` | `string` | `"python3.12"` | Lambda runtime identifier. Supported: `python3.8` through `python3.12` |
| `handler` | `string` | `"index.handler"` | Entrypoint in `file.function` format |
| `package_type` | `string` | `"Zip"` | Deployment package type. `Zip` or `Image` (no image support in this module) |
| `local_zip_deployment` | `bool` | `true` | `true` = deploy from local zip (`filename` + `source_code_hash`). `false` = deploy from S3 (`s3_bucket` + `s3_key`) |
| `filename` | `string` | `null` | Path to local `.zip` file. Used when `local_zip_deployment = true` |
| `source_code_hash` | `string` | `null` | `filebase64sha256()` of the zip. Forces re-deploy on change. Used when `local_zip_deployment = true` |
| `s3_bucket` | `string` | `null` | S3 bucket of the deployment package. Used when `local_zip_deployment = false` |
| `s3_key` | `string` | `null` | S3 object key of the deployment package. Used when `local_zip_deployment = false` |
| `s3_object_version` | `string` | `null` | Specific S3 object version to deploy. Used when `local_zip_deployment = false` |

### Architecture & Performance

| Variable | Type | Default | Description |
|---|---|---|---|
| `architectures` | `list(string)` | `["x86_64"]` | Instruction set. `x86_64` or `arm64` (arm64 is cheaper for Python) |
| `memory_size` | `number` | `1024` | Memory in MB. Range: 128–10240 |
| `timeout` | `number` | `900` | Execution timeout in seconds. Range: 1–900 |
| `ephemeral_storage_size` | `number` | `null` | `/tmp` directory size in MB. Range: 512–10240. Omit to use the AWS default (512 MB) |
| `reserved_concurrent_executions` | `number` | `-1` | Max concurrent executions. `-1` = no limit, `0` = throttle all |

### Versioning & Publishing

| Variable | Type | Default | Description |
|---|---|---|---|
| `publish` | `bool` | `false` | Publish a new numbered version on every deployment |
| `skip_destroy` | `bool` | `false` | Prevent Terraform from deleting the function on `destroy` |

### IAM Role

| Variable | Type | Default | Description |
|---|---|---|---|
| `create_iam_role` | `bool` | `true` | Create a new execution role. Set `false` to bring your own via `iam_role_arn` |
| `iam_role_arn` | `string` | `null` | ARN of an existing role. Used only when `create_iam_role = false` |
| `iam_role_name` | `string` | `null` | Override the auto-generated role name (`<function_name>-role`) |
| `attach_vpc_policy` | `bool` | `false` | Attach `AWSLambdaVPCAccessExecutionRole`. Required with `vpc_config` |

### Environment Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `environment_variables` | `map(string)` | `null` | Key/value pairs injected into the Lambda runtime |

### Encryption

| Variable | Type | Default | Description |
|---|---|---|---|
| `kms_key_arn` | `string` | `null` | KMS key ARN to encrypt environment variables and the CloudWatch log group |

### VPC Configuration

| Variable | Type | Default | Description |
|---|---|---|---|
| `vpc_config` | `object` | `null` | Place the function inside a VPC. Requires `attach_vpc_policy = true` |
| `vpc_config.subnet_ids` | `list(string)` | **required** | Subnets the function will run in |
| `vpc_config.security_group_ids` | `list(string)` | **required** | Security groups attached to the function |
| `vpc_config.ipv6_allowed_for_dual_stack` | `bool` | `false` | Allow IPv6 traffic in a dual-stack VPC |
| `replace_security_groups_on_destroy` | `bool` | `null` | Replace security groups with `replacement_security_group_ids` before destroying |
| `replacement_security_group_ids` | `list(string)` | `null` | Security groups to substitute during destroy |

### Dead Letter Queue

| Variable | Type | Default | Description |
|---|---|---|---|
| `dead_letter_target_arn` | `string` | `null` | ARN of an SQS queue or SNS topic for unprocessable events |

### Logging

| Variable | Type | Default | Description |
|---|---|---|---|
| `cloudwatch_log_group_retention_days` | `number` | `14` | Log retention in days. `0` = never expire |
| `logging_config` | `object` | `null` | Advanced logging configuration (see below) |
| `logging_config.log_format` | `string` | **required** | `JSON` for structured logs, `Text` for plain text |
| `logging_config.log_group` | `string` | `/aws/lambda/<name>` | Custom CloudWatch log group name |
| `logging_config.application_log_level` | `string` | `null` | JSON only. One of `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL` |
| `logging_config.system_log_level` | `string` | `null` | JSON only. One of `DEBUG`, `INFO`, `WARN` |

### EFS File System

| Variable | Type | Default | Description |
|---|---|---|---|
| `file_system_config` | `object` | `null` | Mount an EFS access point into the Lambda environment |
| `file_system_config.arn` | `string` | **required** | EFS access point ARN |
| `file_system_config.local_mount_path` | `string` | **required** | Mount path inside the function. Must start with `/mnt/` |

### Alias

| Variable | Type | Default | Description |
|---|---|---|---|
| `create_alias` | `bool` | `false` | Create a Lambda alias |
| `alias_name` | `string` | `"live"` | Name for the alias (e.g. `live`, `stable`, `v1`) |
| `alias_description` | `string` | `""` | Description for the alias |
| `alias_routing_config` | `map(number)` | `null` | Weighted traffic split between two versions. e.g. `{ "2" = 0.1 }` |

### Provisioned Concurrency

| Variable | Type | Default | Description |
|---|---|---|---|
| `provisioned_concurrent_executions` | `number` | `0` | Number of warm execution environments to maintain. Requires `publish = true` |

### Function URL

| Variable | Type | Default | Description |
|---|---|---|---|
| `create_function_url` | `bool` | `false` | Expose the function via a direct HTTPS endpoint |
| `function_url_authorization_type` | `string` | `"AWS_IAM"` | `AWS_IAM` = IAM-signed requests only, `NONE` = public |
| `function_url_invoke_mode` | `string` | `"BUFFERED"` | `BUFFERED` = full response, `RESPONSE_STREAM` = streaming |
| `function_url_cors` | `object` | `null` | CORS settings: `allow_origins`, `allow_methods`, `allow_headers`, `expose_headers`, `allow_credentials`, `max_age` |

### Asynchronous Invocation

| Variable | Type | Default | Description |
|---|---|---|---|
| `maximum_event_age_in_seconds` | `number` | `null` | How long Lambda retains an async event before discarding. Range: 60–21600 |
| `maximum_retry_attempts` | `number` | `null` | Retry attempts for failed async invocations. Range: 0–2 |
| `destination_on_success_arn` | `string` | `null` | Destination ARN (SQS, SNS, Lambda, EventBridge) on async success |
| `destination_on_failure_arn` | `string` | `null` | Destination ARN (SQS, SNS, Lambda, EventBridge) on async failure |

### Lambda Permissions (Triggers)

| Variable | Type | Default | Description |
|---|---|---|---|
| `allowed_triggers` | `map(object)` | `{}` | Map of `aws_lambda_permission` resources to create. Each key is a trigger name |
| `allowed_triggers.<key>.principal` | `string` | **required** | AWS service principal (e.g. `apigateway.amazonaws.com`) |
| `allowed_triggers.<key>.source_arn` | `string` | `null` | ARN of the triggering resource |
| `allowed_triggers.<key>.source_account` | `string` | `null` | AWS account ID of the trigger source |
| `allowed_triggers.<key>.action` | `string` | `"lambda:InvokeFunction"` | IAM action to permit |
| `allowed_triggers.<key>.qualifier` | `string` | alias name | Version or alias qualifier to scope the permission |

---

## Outputs

| Output | Description |
|---|---|
| `function_arn` | ARN of the Lambda function |
| `function_name` | Name of the Lambda function |
| `function_invoke_arn` | Invoke ARN for use with API Gateway / Step Functions |
| `function_qualified_arn` | ARN including the version number |
| `function_version` | Latest published version number |
| `function_last_modified` | Timestamp of the last deployment |
| `function_source_code_hash` | SHA256 hash of the current deployment package |
| `function_source_code_size` | Size of the deployment package in bytes |
| `iam_role_arn` | ARN of the Lambda execution IAM role |
| `iam_role_name` | Name of the Lambda execution IAM role |
| `log_group_name` | CloudWatch log group name |
| `log_group_arn` | CloudWatch log group ARN |
| `alias_arn` | ARN of the Lambda alias (`null` if not created) |
| `alias_invoke_arn` | Invoke ARN of the alias (use in API Gateway integrations) |
| `alias_name` | Name of the Lambda alias |
| `function_url` | HTTPS Function URL endpoint (`null` if not created) |
| `function_url_id` | Unique ID of the Function URL |

---

## File Structure

```
modules/compute/
├── variables.tf   # All input variable declarations
├── main.tf        # All resource definitions
├── output.tf      # All output values
└── dev.tfvars     # Example values for a development environment
```