# Compute Module — AWS Lambda

Provisions an AWS Lambda function with IAM role, CloudWatch Logs, aliases, provisioned concurrency, Function URLs, async invocation, and trigger permissions.

> Container images and Lambda Layers are not supported.

## Usage

```hcl
module "compute" {
  source = "./modules/compute"

  function_name    = "my-python-lambda"
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = "./function.zip"
  source_code_hash = filebase64sha256("./function.zip")
  memory_size      = 256
  timeout          = 60

  environment_variables = {
    ENVIRONMENT = "dev"
  }

  tags = { Environment = "dev" }
}
```

## Key Variables

| Variable | Default | Description |
|---|---|---|
| `function_name` | **required** | Unique Lambda function name |
| `runtime` | `python3.12` | Lambda runtime identifier |
| `handler` | `index.handler` | Entrypoint in `file.function` format |
| `filename` | `null` | Path to local `.zip` (local deployment) |
| `source_code_hash` | `null` | `filebase64sha256()` of the zip |
| `s3_bucket` / `s3_key` | `null` | S3 deployment (set `local_zip_deployment = false`) |
| `memory_size` | `1024` | MB. Range: 128–10240 |
| `timeout` | `900` | Seconds. Range: 1–900 |
| `architectures` | `["x86_64"]` | `x86_64` or `arm64` |
| `create_iam_role` | `true` | Set `false` to supply `iam_role_arn` |
| `publish` | `false` | Publish a numbered version on each deploy |
| `create_alias` | `false` | Create a Lambda alias |
| `create_function_url` | `false` | Expose a direct HTTPS endpoint |
| `vpc_config` | `null` | VPC placement (requires `attach_vpc_policy = true`) |
| `environment_variables` | `null` | Runtime env vars |
| `kms_key_arn` | `null` | KMS key for env var and log encryption |
| `cloudwatch_log_group_retention_days` | `14` | Log retention in days |
| `allowed_triggers` | `{}` | Map of `aws_lambda_permission` resources |

## Outputs

| Output | Description |
|---|---|
| `function_arn` | Lambda function ARN |
| `function_name` | Lambda function name |
| `function_invoke_arn` | Invoke ARN (for API Gateway / Step Functions) |
| `function_url` | HTTPS Function URL (`null` if not enabled) |
| `alias_arn` | Alias ARN (`null` if not created) |
| `iam_role_arn` | Execution role ARN |
| `log_group_name` | CloudWatch log group name |

## Files

```
modules/compute/
├── main.tf        # Resources
├── variables.tf   # Inputs
└── output.tf      # Outputs
```
