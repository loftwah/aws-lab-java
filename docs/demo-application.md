# Demo Application Blueprint

The demo service showcases the AWS Lab Java platform by exercising key infrastructure components from both ECS Fargate and EC2 (Ubuntu) deployments.

## Functional goals

- Serve a branded landing page at `/` describing the lab, owner (Dean Lofts), and runtime mode (ECS vs EC2).
- Expose `/healthz` returning readiness + dependency status (RDS connectivity, Secrets Manager token retrieval, S3 reachability).
- Provide authenticated CRUD APIs for sample resources (`/api/v1/widgets`) backed by the shared PostgreSQL database (persisted via JPA/Flyway migrations). Mutating operations require the `X-Demo-Auth` header matching the Secrets Manager token.
- Demonstrate optional AWS integrations (e.g. uploading metadata to S3) gated behind feature flags.
- Emit structured logs with correlation IDs for every request and dependency call.

```mermaid
graph TD
  Client -->|HTTPS (ALB)| Service
  Service -->|JDBC| RDS[(PostgreSQL)]
  Service -->|GetParameter| SSM{{Parameter Store}}
  Service -->|GetSecretValue| SecretsManager
  Service -->|PutObject metadata| S3[(App bucket)]
  Service -->|Logs| CloudWatch
```

## Runtime behaviours

- Single Docker image (Java 21 LTS) deployed on both ECS and EC2; runtime determines platform via `DEPLOYMENT_TARGET` env var (`ecs`/`ec2`).
- EC2 hosts use the latest Ubuntu LTS AMI; Ansible playbooks install Docker, CloudWatch agent, and drop a systemd unit to run the container.
- ECS tasks define FireLens/CloudWatch log drivers for structured JSON entries with 30-day retention.
- Application uses Micrometer/Actuator (if Spring) to publish metrics consumed by CloudWatch dashboards later.

## Authentication & configuration

- Per-environment `DEMO_AUTH_TOKEN` stored in Secrets Manager; middleware enforces it for any mutating API.
- Configuration hierarchy: environment variables > Parameter Store secure strings > sensible defaults baked into the image (for local dev only).
- Database migrations run on startup using Flyway/Liquibase; a feature flag toggles destructive operations per environment.

## Observability checklist

- Request/response logs: `traceId`, `spanId`, `deploymentTarget`, `serviceVersion` (commit SHA), latency, status code.
- Dependency logs: call type, target ARN/ID, duration, error classification.
- Slash `/healthz` returns JSON including `status`, `rds`, `secretsManager`, `s3`, `buildInfo`.
- Metrics: request rate, error %, P95/P99 latency, DB connection pool saturation.
- Alerts (later lab): availability drop, 5xx spike, DB connection exhaustion.

## Build & packaging

- `scripts/build-demo.sh` builds multi-arch Docker images on macOS/ARM using `docker buildx` (outputs `amd64` by default for ECS/EC2); supply `PUSH=true` to publish to ECR once credentials are configured.
- Local build uses Maven/Gradle wrapper inside the repo; SBOM generation via `syft` (CodeBuild stage will mirror).
- Image tags: `sha-<short>` and `latest`, matching the Terraform/ECR policy documented in `docs/terraform-approach.md`.
- Integration tests run via Testcontainers-backed PostgreSQL to validate CRUD behaviour before publishing images.

## Ansible integration (EC2 track)

1. Terraform provisions EC2 Auto Scaling Group + IAM instance profile with SSM access.
2. SSM State Manager association triggers Ansible playbook stored in the repo (`ansible/playbooks/ec2-demo.yml`).
3. Playbook tasks:
   - Install Docker + dependencies on Ubuntu.
   - Configure CloudWatch Agent with log collection for `/var/log/cloud-init.log` and container stdout/stderr.
   - Pull the versioned container image from ECR.
   - Render `.env` from Parameter Store/Secrets Manager values.
   - Start/enable systemd unit managing the container.

## Open questions

- Do we need additional CRUD integrations (e.g. DynamoDB) or keep scope to RDS + S3 metadata?
- Should `/healthz` self-test ALB headers or rely on runtime metrics?
- How much of the Ansible runbook should be reusable vs bespoke to this demo?
