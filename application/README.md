# AWS Lab Java Demo Application

## Prerequisites

- Java 21 (for local development)
- Gradle 8.7+ (optional if using Docker build only)
- Docker with BuildKit / buildx enabled

## Run locally

```bash
./gradlew bootRun
```

By default the service listens on `http://localhost:8080` and uses placeholder configuration values. Override via environment variables:

```bash
export DEPLOYMENT_TARGET=local
export DEMO_AUTH_TOKEN=local-token
./gradlew bootRun
```

## Docker build

Use the helper script in the repo root:

```bash
./scripts/build-demo.sh IMAGE_NAME=aws-lab-java/demo-app
```

Set `PUSH=true` to push to ECR once authentication is configured.

## Key endpoints

- `GET /` – Landing page with deployment metadata.
- `GET /healthz` – Readiness + dependency summary.
- `GET /api/v1/widgets` – List sample widgets.
- `POST /api/v1/widgets` – Create widget (requires `X-Demo-Auth` header matching `DEMO_AUTH_TOKEN`).
