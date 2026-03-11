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

## CI/CD — GitHub Actions

The workflow at [`.github/workflows/terraform.yml`](../.github/workflows/terraform.yml) runs automatically:

| Event | What happens |
|---|---|
| Pull request to `main` | `init` → `fmt check` → `validate` → `plan` (result posted as PR comment) |
| Push / merge to `main` | Same as above, then `apply` |

The workflow only triggers when files inside `aws-terra/` change.

### One-time setup

#### 1. Create an IAM OIDC Identity Provider for GitHub

In the AWS Console → IAM → Identity Providers → Add provider:

- Provider type: **OpenID Connect**
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

#### 2. Create an IAM Role for GitHub Actions

Create a role with a trust policy that allows your repo to assume it:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<YOUR_ORG>/<YOUR_REPO>:*"
        }
      }
    }
  ]
}
```

Attach a policy granting the permissions Terraform needs (Lambda, S3, Secrets Manager, IAM, CloudWatch Logs).

#### 3. Add the GitHub secret

In your GitHub repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>` |

#### 4. (Optional) Add a Terraform backend for remote state

Add an S3 backend to `providers.tf` so state is shared across runs:

```hcl
terraform {
  backend "s3" {
    bucket = "your-tfstate-bucket"
    key    = "pos-pipeline/dev/terraform.tfstate"
    region = "us-east-1"
  }
}
```

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
