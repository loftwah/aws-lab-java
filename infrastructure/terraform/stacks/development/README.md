# Development stacks

Each subdirectory is an independently runnable Terraform stack with its own backend key in the shared S3 bucket. Apply stacks in a sensible order (e.g. `core-networking` before `compute-ecs`).

```
cd infrastructure/terraform/stacks/development/core-networking
terraform init
terraform plan
terraform apply
```

Add new stacks (e.g. `database`, `compute-ecs`, `cicd`) by copying the provider/variable boilerplate and pointing the backend key to `development/<stack>.tfstate`.
