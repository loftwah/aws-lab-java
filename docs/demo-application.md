# Demo Application Blueprint

The Spring Boot demo service demonstrates how the AWS Lab Java platform hangs together. It provides a simple CRUD workflow, health introspection, and structured logging so we can exercise VPC networking, load balancers, ECS/EC2 scheduling, and RDS PostgreSQL.

```mermaid
graph TD
  subgraph AWS Runtime
    ALB --> Service
    Service -->|JDBC| RDS[(PostgreSQL 16)]
    Service -. optional .->|putObject metadata| S3[(App bucket)]
    Service -->|stdout json| CloudWatch
  end
  DevLaptop -->|docker compose| Service
```

## What the service does today

- Serves a branded landing page at `/` that highlights the deployment target (local, ECS, EC2, etc.).
- Exposes `/healthz` with readiness metadata, timestamp, and dependency placeholders so platform teams can wire automated checks.
- Provides authenticated CRUD APIs at `/api/v1/widgets` backed by PostgreSQL via Spring Data JPA and Flyway migrations.
- Guards mutating endpoints with the `X-Demo-Auth` header. Tokens load from AWS Secrets Manager (preferred) or SSM Parameter Store, falling back to environment variables only for local work.
- Emits structured request logs with per-request trace IDs, latency, HTTP status, and the resolved deployment target.
- Ships with a smoke test script (`scripts/demo-smoke.sh`) that exercises health + CRUD using the local auth token.

## Runtime & AWS compatibility

- **Java & framework**: Java 21 LTS on Spring Boot 3.3.2. Container image built via a multi-stage Dockerfile using `gradle:8.7-jdk21` for compilation and `eclipse-temurin:21-jre` for runtime.
- **Database**: Uses the official PostgreSQL JDBC driver and Flyway 10.22.0 (with the PostgreSQL plugin) so PostgreSQL 16.10 in AWS RDS/Aurora works out of the box.
- **Networking**: Binds to port `8080` by default; override with `SERVER_PORT`. Works behind ALB/NLB when health checks use `/healthz`.
- **AWS services**:
  - RDS PostgreSQL connectivity is exercised on startup and via health probes.
  - Secrets Manager is the default source of the `DEMO_AUTH_TOKEN`; Parameter Store serves as a fallback when a secret id is not provided.
  - S3 metadata writes run on every widget mutation when `FEATURE_S3_METADATA=true` and the bucket is configured. Failures surface to callers.
  - IAM interaction is handled by the hosting platform; grant scoped permissions for RDS, Secrets Manager/SSM, and the configured S3 bucket.
- **Deployment targets**: Set `DEPLOYMENT_TARGET` (e.g. `ecs`, `ec2`, `local`, `dev`) in the task definition or systemd unit. The landing page and logs surface this value so it is obvious where the container is running. If the value is omitted we fall back to `local`.

## Configuration reference

| Property                                        | Environment variable               | Default                                 | Purpose                                                                                                         |
| ----------------------------------------------- | ---------------------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `app.deployment-target`                         | `DEPLOYMENT_TARGET`                | `local`                                 | Displayed on the landing page and emitted in logs. Set to `ecs`, `ec2`, or environment names like `dev`/`prod`. |
| `app.auth-token`                                | `DEMO_AUTH_TOKEN`                  | `demo-token`                            | Shared secret for CRUD operations. Overridden automatically when Secrets Manager/SSM sources are configured.    |
| `app.feature.s3-metadata`                       | `FEATURE_S3_METADATA`              | `false`                                 | Enables S3 metadata writes. Requires the bucket configuration below.                                            |
| `spring.datasource.url`                         | `SPRING_DATASOURCE_URL`            | `jdbc:postgresql://localhost:5432/demo` | JDBC URL for RDS.                                                                                               |
| `spring.datasource.username`                    | `SPRING_DATASOURCE_USERNAME`       | `demo`                                  | Database user.                                                                                                  |
| `spring.datasource.password`                    | `SPRING_DATASOURCE_PASSWORD`       | `demo`                                  | Database password.                                                                                              |
| `server.port`                                   | `SERVER_PORT`                      | `8080`                                  | HTTP port.                                                                                                      |
| `aws.region`                                    | `AWS_REGION`                       | _(empty)_                               | Explicit AWS region for SDK clients. Defaults to the standard provider chain if omitted.                        |
| `aws.secrets.auth-token-secret-id`              | `AWS_SECRETS_AUTH_TOKEN_SECRET_ID` | _(empty)_                               | Secrets Manager secret ID containing the demo auth token. Takes precedence over all other sources.              |
| `aws.parameter-store.auth-token-parameter-name` | `AWS_SSM_AUTH_TOKEN_PARAMETER`     | _(empty)_                               | SecureString parameter name for the auth token when a secret id is not supplied.                                |
| `aws.s3.bucket-name`                            | `AWS_S3_METADATA_BUCKET`           | _(empty)_                               | Bucket used for widget metadata. Mandatory when S3 metadata is enabled.                                         |
| `aws.s3.prefix`                                 | `AWS_S3_METADATA_PREFIX`           | `widget-metadata/`                      | Key prefix applied to every widget metadata object.                                                             |

All configuration ultimately binds through Spring Boot configuration properties. That lets us provide values via:

1. **Local overrides** – pass `--env` flags to `docker run`/Compose.
2. **ECS task definitions** – use task definition environment blocks or reference Secrets Manager/SSM parameters.
3. **EC2 systemd unit** – write an `.env` file sourced by the unit, populated via SSM/Secrets Manager during provisioning.

## Health and observability

- `/healthz` now performs live checks:
  ```json
  {
    "status": "UP",
    "timestamp": "2025-09-18T13:51:30.097Z",
    "deploymentTarget": "ecs",
    "dependencies": {
      "rds": {
        "status": "UP",
        "validationQuery": "connection.isValid",
        "details": { "valid": true }
      },
      "authToken": {
        "status": "UP",
        "source": "SECRETS_MANAGER",
        "fetchedAt": "2025-09-18T13:51:28.320Z"
      },
      "s3": { "status": "UP", "bucket": "aws-lab-java-widget-metadata" }
    },
    "buildInfo": { "service": "AWS Lab Java Demo" }
  }
  ```
  Misconfiguration (missing secret, failed parameter read, no S3 bucket) surfaces as `DOWN` so load balancers and synthesis catch it immediately.
- `RequestLoggingFilter` adds a structured log line for every HTTP request:
  ```
  requestHandled traceId=038f... method=POST path=/api/v1/widgets status=201 durationMs=42 deploymentTarget=ecs
  ```
  When shipped to CloudWatch Logs (via FireLens/CloudWatch agent) these fields make it easy to build latency/error dashboards.
- Future labs can extend the same pattern for downstream calls (S3, Secrets Manager) and adopt Micrometer metrics.

## Build, test, and release flow

1. `scripts/build-demo.sh` drives `docker buildx build` so we generate reproducible container images tagged as `latest` and `sha-<git short sha>`. Use `PUSH=true` when running in CI to publish to ECR.
2. `gradle test` runs integration tests powered by Testcontainers PostgreSQL.
3. `scripts/demo-smoke.sh` waits for `/healthz`, creates a widget, lists widgets, and deletes it – perfect for post-deploy validation in any environment.

## Roadmap hooks

- **Secrets rotation**: add automated rotation support for the demo auth token and ensure the provider refreshes without manual intervention.
- **S3 metadata enrichment**: expand metadata with object versioning and checksum validation once the bucket lifecycle policy is defined.
- **Smoke test hardening**: extend `demo-smoke.sh` to cover widget `GET /{id}` + `PUT`, assert `/healthz` dependency statuses, and prove auth failures + S3 metadata paths.
- **Distributed tracing**: propagate the generated trace ID via headers so future services can join the trace.

Keep this document up to date as new AWS integrations land so anyone skimming the repo understands the shape of the demo service and how to operate it.
