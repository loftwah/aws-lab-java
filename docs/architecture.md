# AWS Lab Java Architecture Overview

## Accounts, region and tooling

- **AWS region:** `ap-southeast-2`
- **AWS profile:** `devops-sandbox`
- **Infrastructure as code:** Terraform ≥1.13 with S3-backed state files (no DynamoDB locking)
- **Configuration management:** Ansible for EC2 bootstrap (Docker, JVM, app)
- **Source-of-truth:** Mono-repo (`aws-lab-java`) containing app, IaC, automation, docs

## Domain & DNS

- Route53 public hosted zone `aws.deanlofts.xyz` already exists; Terraform manages `java-demo-ecs.aws.deanlofts.xyz` and `java-demo-ec2.aws.deanlofts.xyz` records.
- ACM certificates issued in `ap-southeast-2` for the subdomains; ALBs terminate HTTPS and forward HTTP internally.
- Future labs can layer WAF/Shield if exposure increases.

## Networking baseline (reused)

- Pre-provisioned VPC `vpc-075f21399ed8cdd47`
  - Public subnets: `subnet-0dd3f7f05ca1cb8d8`, `subnet-0b7e614d07d9f6030`
  - Private subnets: `subnet-03d29cbce89aeaf14`, `subnet-081e4da6ba7b7046e`
- Terraform will import the VPC and subnets via `data` sources
- Separate security groups per tier (ingress, app, database, bastion) with least-privilege rules
- NAT gateway shared for private subnet egress; SSM traffic allowed without public IP
- VPC endpoints: S3 gateway plus interface endpoints for SSM, SSM Messages, EC2 Messages, ECR (`api`/`dkr`), CloudWatch Logs, and Secrets Manager to keep private subnets off the public internet.

## Runtime strategy (two delivery patterns)

### ECS Fargate service

- Dedicated ECS cluster (Fargate launch type) with services deployed in the private subnets
- Dedicated application load balancer in public subnets with HTTPS (ACM cert) serving `java-demo-ecs.aws.deanlofts.xyz`; listener health checks mapped to app readiness endpoint.
- Task definitions built from container images published to ECR by CodePipeline/CodeBuild
- CloudWatch Logs groups per service; X-Ray tracing optional toggle

### EC2-based service (Docker on EC2)

- Auto Scaling Group with launch templates pinned to the latest Ubuntu LTS AMIs (Java 21 runtime baked via Ansible).
- Bootstrap handled by Ansible (via SSM) installing Docker, runtime dependencies and deploying the app container.
- Systemd unit manages the container lifecycle; log forwarding via CloudWatch agent.
- Separate application load balancer fronts the EC2 service at `java-demo-ec2.aws.deanlofts.xyz`.
- Demonstrates traditional VM operations alongside container-first approach.

## Application behaviour

- Detailed behaviour documented in `docs/demo-application.md`.
- Single Java 21 Docker image serves both ECS and EC2 deployments; runtime identifies its platform via `DEPLOYMENT_TARGET` env var for logging/telemetry.
- Shared RDS PostgreSQL database handles CRUD features for both services; schema changes coordinated via migration tooling baked into the build.
- Service exposes CRUD APIs for core resources (TBD) with optional AWS integrations (e.g. S3 object metadata) gated behind authenticated endpoints.
- Auth token (per environment) supplied via Secrets Manager/Parameter Store; middleware validates before touching sensitive operations.
- Feature flags allow optional integrations (e.g. Redis) without impacting lab scope.

## Bastion and access model

- Default access via AWS Systems Manager Session Manager (audited, no inbound SSH).
- Lightweight bastion host (t3.micro) in public subnet, hardened with SSM, used when interactive network access to private resources is unavoidable (e.g. psql).
- Bastion security group only allows SSM and controlled outbound to RDS/S3; IAM Session policies enforce time-bounded access.
- ADR will compare SSM + bastion pattern with alternatives such as SSH tunnelling or Tailscale to document trade-offs.

## Database layer (PostgreSQL)

- Amazon RDS for PostgreSQL 15, single-AZ for the lab to minimise cost; blueprint includes parameter to switch on Multi-AZ for higher environments
- Instance class: `db.t4g.micro` (baseline) with automated backups (7 days) and snapshots on destroy via `deletion_protection = true` toggleable per env
- Performance insights + enhanced monitoring enabled for observability
- Secrets stored in AWS Secrets Manager, rotated via Lambda (future enhancement)
- Single database instance shared by ECS and EC2 services; app-level tenancy controls protect per-service namespaces.

## CI/CD pipeline

- CodePipeline orchestrating stages: Source (CodeCommit/GitHub), Build (CodeBuild), Test, Image Push (ECR), Deploy (ECS/EC2 targets).
- CodeBuild assembles the Docker image, runs tests, and tags outputs with both the Git commit SHA (`sha-<short>`) and `latest`; Terraform provisions an immutable ECR repository that enforces this policy.
- Pipelines use OIDC/IAM Roles for Service Accounts (no static keys) with dedicated Terraform-managed roles granting least-privilege pushes, deploys, and Terraform plan/apply.
- Unit tests, static analysis, dependency scans, and container scans (e.g. Trivy) run inside CodeBuild; SBOMs and reports shipped as artefacts.
- Promotion via manual approval to production-like env; same artefact promoted through stages using environment-specific Terraform apply jobs.

## Logging, metrics and observability

- CloudWatch Logs for application/system logs with standard log group naming convention `/aws/labs/java/<service>/<env>`; Terraform manages retention (30 days default).
- ECS tasks stream logs via the `awslogs`/FireLens driver; EC2 hosts run the CloudWatch Agent (installed via Ansible) to ship `/var/log/syslog`, `/var/log/cloud-init.log`, and container stdout/stderr.
- CloudWatch metrics dashboards for ALB, ECS, EC2, RDS.
- Alarm catalogue tied to SLOs (availability, latency, error budget burn).
- Structured JSON logging with correlation IDs from the app; optional OpenTelemetry traces to X-Ray/Grafana-Agent.

## Security & compliance (SOC 2 aware)

- Centralised IAM module generating least-privilege roles/policies for pipelines, with workload-specific IAM/SG resources defined within their respective modules.
- KMS CMKs for secrets, EBS, and RDS storage encryption.
- CloudTrail + Config enabled (future lab) for audit evidence retention.
- Threat modelling tracked via STRIDE template; secure defaults baked into Terraform (no public DB, restricted ALB, TLS only).

## Tagging strategy

All provisioned resources inherit Terraform `default_tags`:

```
Owner       = "Dean Lofts"
Environment = "development" (varies per env)
Project     = "aws-lab-java"
App         = "aws-lab-java"
ManagedBy   = "Terraform"
CostCenter  = "platform-engineering" (example extra tag)
```

- Module inputs override only when necessary (e.g. per-service `Component` tag)
- Tag compliance validated via `terraform validate` custom checks or `tfsec` policy packs later

## Governance hooks

- Architecture Decisions captured under `docs/adrs/ADR-XXXX.md`
- Definition of Done includes security review, threat model update, runbook entry, observability check
- Environments: `development` (default), `staging`, `production` with change windows and promotion rules documented

## Next steps (labs sequencing)

1. **Lab 00 – Foundation:** Bootstrap repo structure, Terraform backend (see `docs/state-bootstrap.md`), providers, tagging.
2. **Lab 01 – Networking data sources & security groups:** Model existing VPC, create core SGs, IAM baseline.
3. **Lab 02 – RDS PostgreSQL:** Provision development DB, parameter groups, networking.
4. **Lab 03 – ECR & build pipeline:** Create ECR repo, CodeBuild project, CodePipeline skeleton.
5. **Lab 04 – ECS Fargate service:** Cluster, task/service, ALB integration, logging.
6. **Lab 05 – EC2 variant with Ansible:** Launch template, ASG, SSM association, playbook skeleton.
7. **Lab 06 – Bastion & access controls:** Session Manager, security posture, audit trail.
8. **Lab 07 – Observability & alarms:** CloudWatch dashboards, alarms, log retention.
9. **Lab 08 – Compliance wraps:** Threat model doc, runbooks, backup tests.

Each lab will include ADR updates, test evidence, and cost notes before promotion.
