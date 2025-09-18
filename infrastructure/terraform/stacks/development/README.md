# Development stacks

Each subdirectory is an independently runnable Terraform stack with its own backend key in the shared S3 bucket. Apply stacks in a sensible order (e.g. `core-networking` before `compute-ecs`, `database`, `cicd`).

```
cd infrastructure/terraform/stacks/development/core-networking
terraform init
terraform plan
terraform apply
```

Current stacks:

- `core-networking` – data sources and shared networking outputs.
- `compute-ecs` – ECR repository (ECS service wiring later).
- `compute-ec2` – placeholder for EC2/Ansible resources.
- `database` – placeholder for RDS/Secrets.
- `cicd` – placeholder for CodePipeline/CodeBuild artefacts.
- `observability` – placeholder for logs/dashboards/alarms.

Add or expand stacks by copying the provider/variable boilerplate and pointing the backend key to `development/<stack>.tfstate`.

## State backend and locking

- All stacks use the S3 backend in bucket `aws-lab-java-terraform-state`.
- Terraform v1.13.x with native S3 locking is enabled via `use_lockfile = true` in each backend block. This provides state locking without DynamoDB.
- The state bucket has versioning and server-side encryption enabled in `infrastructure/terraform/modules/state_bucket`.
- If a run is force-terminated, you may need to remove the temporary `.tflock` object from the state key prefix to release the lock.
