# aws-terra

Terraform configuration for the `pos-pipeline` project. Provisions AWS Lambda functions, S3 buckets, Secrets Manager secrets, and Lambda layers.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with appropriate credentials
- AWS credentials with permissions to manage Lambda, S3, Secrets Manager, IAM, and CloudWatch Logs

## Project Structure

```
.
├── main.tf           # Root module — wires together all child modules
├── variables.tf      # Input variable definitions
├── outputs.tf        # Output values
├── providers.tf      # AWS provider and Terraform version constraints
├── dev.tfvars        # Variable values for the dev environment
└── modules/
    ├── compute/      # Lambda function and layer modules
    ├── storage/      # S3 bucket module
    └── secrets/      # Secrets Manager module
```

## Usage

### 1. Configure AWS credentials

```bash
aws configure
# or export environment variables:
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the plan

```bash
terraform plan -var-file=dev.tfvars
```

### 4. Apply

```bash
terraform apply -var-file=dev.tfvars
```

### 5. Destroy (when done)

```bash
terraform destroy -var-file=dev.tfvars
```

## Variables

| Variable | Description | Default |
|---|---|---|
| `aws_region` | AWS region to deploy into | `us-east-1` |
| `environment` | Deployment environment (dev, staging, prod) | `dev` |
| `project` | Project name used for tagging | `aws-terra` |
| `lambda_functions` | Map of Lambda function configurations | see `variables.tf` |
| `lambda_layers` | Map of Lambda layer configurations | `{}` |
| `s3_buckets` | Map of S3 bucket configurations | `{}` |
| `secrets` | Map of Secrets Manager secrets | `{}` |

See [variables.tf](variables.tf) for full type definitions and optional fields.

## Environments

Environment-specific variable files follow the `<env>.tfvars` naming convention:

| File | Environment |
|---|---|
| `dev.tfvars` | Development |

To target a specific environment:

```bash
terraform plan -var-file=<env>.tfvars
terraform apply -var-file=<env>.tfvars
```
