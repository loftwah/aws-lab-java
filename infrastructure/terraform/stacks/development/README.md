# Development stacks

Each subdirectory is an independently runnable Terraform stack with its own backend key in the shared S3 bucket. Apply stacks in a sensible order (e.g. `core-networking` → `compute-ecs-cluster` → `compute-ecs-alb` → service stacks → `database`, `cicd`).

```
cd infrastructure/terraform/stacks/development/core-networking
terraform init
terraform plan
terraform apply
```

Current stacks:

- `core-networking` – data sources plus the shared VPC, subnet catalogues, and network-layer security groups (ALB, ECS, EC2, database, bastion). Keeping SGs here gives every stack a single ingress/egress source of truth.
- `container-registry` – ECR repositories and related policies.
- `security` – IAM roles, instance profiles, secrets, and shared policies that span compute stacks.
- `storage` – Application data stores such as the widget-metadata S3 bucket and related policies.
- `compute-ecs-cluster` – Shared ECS cluster and capacity providers (depends on networking).
- `compute-ecs-alb` – Public application load balancer and base listener for ECS services (depends on networking).
- `compute-ecs-demo-app` – Demo application ECS service and task definition (depends on networking, security, storage, database, container registry, and the ECS cluster/ALB stacks).
- `compute-ec2` – EC2 launch templates, autoscaling, and Ansible bootstrap (depends on networking, security, container registry).
- `database` – RDS/Secrets stack (depends on networking, security).
- `cicd` – CodePipeline/CodeBuild (depends on networking, container registry, security).
- `observability` – Logs, dashboards, alarms.

Add or expand stacks by copying the provider/variable boilerplate and pointing the backend key to `development/<stack>.tfstate`.

## State backend and locking

- All stacks use the S3 backend in bucket `aws-lab-java-terraform-state`.
- Terraform v1.13.x with native S3 locking is enabled via `use_lockfile = true` in each backend block. This provides state locking without DynamoDB.
- The state bucket has versioning and server-side encryption enabled in `infrastructure/terraform/modules/state_bucket`.
- If a run is force-terminated, you may need to remove the temporary `.tflock` object from the state key prefix to release the lock.
