# AWS Lab Java Demo Application

## Prerequisites

- Java 21 (for editing/running the service outside Docker)
- Gradle 8.7+ (`brew install gradle` on macOS, or install via your preferred package manager)
- Docker with BuildKit / buildx enabled
- Docker daemon running (JUnit tests use Testcontainers and will launch PostgreSQL)

## Run locally

```bash
gradle bootRun
```

By default the service listens on `http://localhost:8080` and uses the defaults defined in `src/main/resources/application.yml`. The demo auth token falls back to `demo-token` for local convenience—override it and any other settings via environment variables:

```bash
export DEPLOYMENT_TARGET=local
export DEMO_AUTH_TOKEN=local-token
export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/demo
gradle bootRun
```

## Docker build & smoke tests

Use the helper scripts in the repo root:

```bash
# Build a multi-arch image tagged latest + sha-<commit>
./scripts/build-demo.sh IMAGE_NAME=aws-lab-java/demo-app

# Start postgres + app in the foreground
docker compose up

# Run CRUD smoke tests against http://localhost:8080
./scripts/demo-smoke.sh
```

The smoke script waits for `/actuator/health`, asserts unauthenticated access is blocked, then exercises create/read/list/delete flows to make sure the API and auth token are wired correctly.

Set `PUSH=true` on `build-demo.sh` to push to ECR once authentication is configured.

## AWS runtime configuration

- `AWS_REGION` – optional override when the runtime should bypass the default region provider chain.
- `AWS_SECRETS_AUTH_TOKEN_SECRET_ID` – Secrets Manager secret containing the value that must match `X-Demo-Auth`.
- `AWS_PARAMETER_STORE_AUTH_TOKEN_PARAMETER_NAME` – SecureString parameter name used when a secret id is not set.
- `AWS_S3_BUCKET_NAME` / `AWS_S3_PREFIX` – bucket and prefix for widget metadata. Required when `FEATURE_S3_METADATA=true`.
- `DEMO_AUTH_TOKEN` – static fallback token (defaults to `demo-token`). Always override this outside of local development.

Set the Secrets Manager/SSM variables in your ECS task definition or EC2 `.env` file so the auth token is centrally managed. Grant the task role permissions limited to those resources.

## Logging

Application logs stream to stdout in a key/value format so `docker logs` (and eventually CloudWatch Logs) stay readable:

```
2025-09-19T09:15:00.123+10:00 level=INFO traceId=5e0... thread=http-nio-8080-exec-1 logger=c.d.a.a.filter.RequestLoggingFilter - requestHandled ...
```

`RequestLoggingFilter` now propagates a `traceId` via MDC so every line produced during a request shares the same identifier. The package log level is set to `DEBUG` for richer demo output—tweak via `logging.level.com.deanlofts.awslabjava.application` when you deploy.

## Code style

Spotless with Google Java Format keeps the codebase consistent. Run the formatter before committing:

```bash
gradle spotlessApply
```

CI-friendly check:

```bash
gradle spotlessCheck
```

## Key endpoints

- `GET /` – Landing page with deployment metadata.
- `GET /actuator/health` – Readiness + dependency summary (detailed view requires `ROLE_ACTUATOR`).
- `GET /api/v1/widgets` – List sample widgets.
- `POST /api/v1/widgets` – Create widget (requires `X-Demo-Auth` header matching `DEMO_AUTH_TOKEN`).
