# AWS Lab Java Demo Application

## Prerequisites

- Java 21 (for editing/running the service outside Docker)
- Gradle 8.7+ (installed via [`mise`](https://mise.jdx.dev/) or your preferred package manager)
- Docker with BuildKit / buildx enabled

## Run locally

```bash
gradle bootRun
```

By default the service listens on `http://localhost:8080` and uses the defaults defined in `src/main/resources/application.yml`. Override via environment variables:

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

Set `PUSH=true` on `build-demo.sh` to push to ECR once authentication is configured.

## AWS runtime configuration

- `AWS_REGION` – optional override when the runtime should bypass the default region provider chain.
- `AWS_SECRETS_AUTH_TOKEN_SECRET_ID` – Secrets Manager secret containing the value that must match `X-Demo-Auth`.
- `AWS_SSM_AUTH_TOKEN_PARAMETER` – SecureString parameter name used when a secret id is not set.
- `AWS_S3_METADATA_BUCKET` / `AWS_S3_METADATA_PREFIX` – bucket and prefix for widget metadata. Required when `FEATURE_S3_METADATA=true`.

Set the Secrets Manager/SSM variables in your ECS task definition or EC2 `.env` file so the auth token is centrally managed. Grant the task role permissions limited to those resources.

## Key endpoints

- `GET /` – Landing page with deployment metadata.
- `GET /healthz` – Readiness + dependency summary.
- `GET /api/v1/widgets` – List sample widgets.
- `POST /api/v1/widgets` – Create widget (requires `X-Demo-Auth` header matching `DEMO_AUTH_TOKEN`).
