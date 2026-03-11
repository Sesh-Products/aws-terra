# Secrets Module — AWS Secrets Manager

Provisions a Secrets Manager secret with an optional initial value, resource policy, and automatic rotation.

## Usage

```hcl
module "secrets" {
  source = "./modules/secrets"

  secret_name   = "pos-pipeline/dev/db-password"
  description   = "RDS master password"
  secret_string = jsonencode({ username = "admin", password = "changeme" })

  tags = { Environment = "dev" }
}
```

## Key Variables

| Variable | Default | Description |
|---|---|---|
| `secret_name` | **required** | Secret name. Slashes allowed (e.g. `prod/db/password`) |
| `description` | `""` | Human-readable description |
| `secret_string` | `null` | Plaintext or JSON value to store (sensitive) |
| `kms_key_id` | `null` | KMS key ARN for encryption. Defaults to AWS managed key |
| `recovery_window_in_days` | `30` | Days before permanent deletion. `0` = immediate, or 7–30 |
| `secret_policy` | `null` | JSON IAM resource policy to attach |
| `rotation_lambda_arn` | `null` | Lambda ARN for automatic rotation |
| `rotation_days` | `30` | Days between automatic rotations (1–365) |

## Outputs

| Output | Description |
|---|---|
| `secret_arn` | ARN of the secret |
| `secret_id` | ID of the secret |
| `secret_name` | Name of the secret |
| `secret_version_id` | Version ID of the stored value (`null` if no value set) |

## Files

```
modules/secrets/
├── main.tf        # Resources
├── variables.tf   # Inputs
└── output.tf      # Outputs
```
