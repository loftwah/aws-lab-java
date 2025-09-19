# Terraform Approach

## Versioning and workflow

- Target Terraform `>= 1.13.0` to align with the refreshed AWS provider set and S3-backed state workflow.
- Run Terraform from stack directories under `infrastructure/terraform/stacks/<env>/<stack>`. Each stack is an independent state keyed as `<env>/<stack>.tfstate` in S3 and contains:
  - `backend.tf` – references the shared state bucket with a stack-specific key
  - `providers.tf` – AWS provider with default tags
  - domain files (e.g. `networking.tf`, `rds.tf`, `ecs.tf`) wiring modules for that concern
  - `variables.tf` / `locals.tf` – stack-scoped inputs and tagging defaults
- Bootstrap the shared state bucket via `infrastructure/terraform/state-bootstrap` before touching other stacks. This directory keeps its own local state because it only manages the remote backend (S3 bucket).
- State objects live in S3 (`aws-lab-java-terraform-state`) with versioning/encryption enabled; native S3 locking (`use_lockfile = true`) is enabled instead of DynamoDB.
- Each environment is partitioned into stacks (e.g. `core-networking`, `container-registry`, `storage`, `security`, `compute-ecs`, `cicd`) so you can plan/apply them independently without dragging the entire environment. Network-layer concerns (VPC, subnets, SGs) live in `core-networking`, while IAM/secrets sit in `security`; shared prerequisites (ECR, S3) have their own stacks so compute and pipeline layers depend on the right boundary via remote state.
- Downstream stacks pull networking outputs via `terraform_remote_state` pointing at `development/core-networking.tfstate`.

## Module layout

- `infrastructure/terraform/modules` will contain reusable components:
  - `networking` – shared security groups, VPC lookups, VPC endpoints (S3 gateway, interface endpoints for SSM/ECR/CloudWatch).
  - `rds-postgres` – subnet groups, instances, parameter groups, Secrets Manager integration for shared database credentials.
  - `ecs-cluster` – ECS cluster, capacity providers, CloudWatch logging defaults.
  - `ecs-service` – task definitions, services, autoscaling, target groups; consumes clusters from the dedicated module and security outputs.
  - `ec2-service` – launch templates (Ubuntu LTS), autoscaling groups, IAM instance profiles, SSM associations for Ansible.
  - `alb` – application load balancers, listeners, target groups, WAF hooks, ACM certificates.
  - `route53-records` – DNS records (e.g. `java-demo-ecs.aws.deanlofts.xyz`).
  - `cicd` – CodeStar connections, CodePipeline, CodeBuild, CodeDeploy stages, artefact stores.
  - `bastion` – hardened EC2 instance with Session Manager policies.
  - `observability` – log groups, metrics, alarms, dashboards.
  - `iam` – role/policy bundles for pipelines, runtime services, and humans.
- `ecr-repository` module provisions immutable repositories consumed by the `compute-ecs` stack.
- Modules will expose input variables for tags, environment, naming prefixes, and security constraints, keeping IAM policies and security groups close to the workloads they protect.

## Container image strategy

- Docker images built once and reused across ECS and EC2 to ensure behaviour parity; containers read `DEPLOYMENT_TARGET` env var to detect runtime (e.g. `ecs` vs `ec2`).
- ECR repositories enforce immutable image tags; CodeBuild pushes two tags per build: the Git commit SHA (`sha-<short>`) and `latest`; local builds use `scripts/build-demo.sh` (Docker buildx) to mirror this convention on macOS/ARM.
- Image scanning enabled (ECR vulnerability scans + optional CodeBuild `trivy` step); SBOMs stored as pipeline artefacts.

## Pipeline integration

- **Separation of duties:** GitHub Actions (see `.github/workflows/ci.yml`) is reserved for repository health checks and GHCR publishing only. It must never assume AWS roles for lab resources; all AWS-side automation lives in CodePipeline/CodeBuild.
- CodePipeline orchestrates Source → Build → Test → Scan → Deploy stages for both ECS and EC2 variants.
- Source stage consumes an existing CodeStar Connection (ARN provided via `var.codestar_connection_arn`) so Git pushes to `main` automatically trigger the pipeline.
- CodeBuild builds Docker images, runs unit/integration tests, and pushes to ECR using the Terraform-managed IAM service role; `buildspecs/build-image.yml` enforces tagging conventions.
- Deployment stages trigger Terraform or CD actions with least-privilege IAM roles (`iam` module issues roles for CodePipeline, CodeBuild, and cross-account promotions if needed).
- Pipeline artefacts include Terraform plans, SBOMs, and promotion approvals for SOC2 evidence.

## Networking enhancements

- Networking module provisions VPC endpoints required for private workloads: S3 gateway (bucket access), interface endpoints for `com.amazonaws.<region>.ssm`, `ssmmessages`, `ec2messages`, ECR (`api` + `dkr`), CloudWatch Logs, and optional Secrets Manager.
- ECS tasks and EC2 instances route outbound traffic through the endpoints, avoiding public internet paths.
- Session Manager provides shell access to EC2/bastion without opening SSH; ADR will compare SSM vs SSH/Tailscale.

## EC2 configuration management

- EC2 module provisions Ubuntu LTS AMIs and attaches SSM instance profiles; Ansible playbooks under `ansible/` run via SSM/State Manager to configure Docker and deploy the container.
- Playbooks install and configure the CloudWatch Agent to ship system logs (`/var/log/cloud-init.log`, `/var/log/syslog`) and container stdout/stderr to the appropriate log groups.
- Systemd units manage the container lifecycle and reload environment variables sourced from Parameter Store/Secrets Manager.
- Build outputs (artefacts, inventories) live alongside the repo, keeping automation transparent and versioned.

## Ingress, routing and DNS

- Separate ALBs front the ECS and EC2 services (`java-demo-ecs.aws.deanlofts.xyz`, `java-demo-ec2.aws.deanlofts.xyz`) with HTTPS termination at the load balancer using ACM certificates.
- Route53 zone `aws.deanlofts.xyz` (pre-provisioned) hosts the required `A`/`CNAME` records managed via Terraform.
- ALB listener rules route `/health` to readiness endpoints; WAF hookup reserved for later lab.

## Secrets and runtime identity

- Shared RDS PostgreSQL credentials stored in AWS Secrets Manager; Terraform rotates or imports the secret and maps it into ECS task definitions and EC2 Ansible templates.
- Application auth token generated per environment using `random_password` (stored in Secrets Manager or SSM Parameter Store) unless supplied via `terraform.tfvars`.
- Environment variables supplied via ECS task definitions and SSM Parameter Store for EC2 (Ansible template consumes secure strings).
- Future enhancement: integrate IAM Roles Anywhere / SigV4 for service-to-service auth.

## Logging strategy

- ECS tasks use the `awslogs` driver or FireLens to stream structured JSON logs to CloudWatch (`/aws/labs/java/<service>/<env>`).
- EC2 hosts rely on the CloudWatch Agent configured via Ansible to forward OS logs and container stdout; log retention managed by Terraform (e.g. 30 days).
- Application logs include request metadata, dependency outcomes, and deployment identifiers to support troubleshooting across both runtimes.
- Future enhancement: enable log analytics via CloudWatch Logs Insights or OpenSearch.

## IAM & security groups

- IAM policies live alongside the module that owns the workload to keep least-privilege boundaries explicit (e.g. ECS task role defined in `ecs-service`, pipeline role in `iam`).
- Security groups defined within workload modules, consuming shared data sources for subnets and VPC endpoints while enforcing ingress/egress per tier.
- Reusable policy documents shaped with `aws_iam_policy_document` data sources and exported for auditing.

## Tagging enforcement

- Provider `default_tags` merges `base_tags` with optional per-module additions.
- Modules validate tags via `variable` blocks with `validation` rules ensuring required keys exist.
- Introduce Terraform validation or custom policy (e.g. `terraform validate -json` + `cue` policy) once modules exist.

## Security posture

- Enforce private subnets for application runtimes; only ALB and bastion in public subnets.
- IAM roles generated per workload (ECS task role, execution role, EC2 instance profile) with principle of least privilege.
- SSM Session logging forwarded to CloudWatch Logs/S3 (future lab) for audit.
- Use AWS KMS managed keys for encryption where available (EBS, RDS, Secrets Manager).

## Terraform automation

- Terraform executed via automation jobs (e.g. CodeBuild stage or GitHub Actions runner) that assume read-only roles for `plan` and elevated roles for `apply`.
- Plans must be reviewed and stored as artefacts before `apply` in higher environments; promotion gates enforce this practice.
- For SOC 2 traceability, retain plan/apply logs, approvals, and state diffs.

## Testing strategy

- Use `terraform validate` and `tflint` locally.
- Add `infracost` to track spend once core modules land.
- For modules, add `kitchen-terraform` or `terratest` suites (stretch goal) to validate resources such as security groups.
