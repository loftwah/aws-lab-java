# Terraform State Bootstrap

This lab creates the shared S3 bucket used for all Terraform state files. Run it before any other stack so the remaining workspaces can switch to the S3 backend.

## Prerequisites

- AWS CLI profile `devops-sandbox` configured with rights to create S3 buckets in `ap-southeast-2`.
- Terraform `>= 1.13.0` installed locally.

## Steps

The bucket is shared across all environments. Only the bootstrap stack keeps a local state file; every stack directory (e.g. `infrastructure/terraform/stacks/development/core-networking`) will use the S3 backend after you run `init -migrate-state`.

1. Initialise the bootstrap stack (state file stored alongside the configuration in `infrastructure/terraform/state-bootstrap/`):
   ```bash
   terraform -chdir=infrastructure/terraform/state-bootstrap init
   ```
2. Review and apply the plan:
   ```bash
   terraform -chdir=infrastructure/terraform/state-bootstrap apply
   ```
3. Once the bucket exists, reinitialise each stack so it adopts the S3 backend. Start with core networking:
   ```bash
   terraform -chdir=infrastructure/terraform/stacks/development/core-networking init -migrate-state
   ```

> **Note:** No DynamoDB locking table is created by design. Coordinate `terraform apply` runs to avoid concurrent writers, or add a table later if contention becomes a risk.
