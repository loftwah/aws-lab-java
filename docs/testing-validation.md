# Testing & Validation Strategy

This repo demonstrates how a senior DevOps engineer would prove changes locally before touching AWS infrastructure. The approach layers fast feedback (unit/integration), container verification, and Terraform checks so each slice can be validated independently.

## Application testing

### Unit & integration tests

- Run from the `application/` directory using the mise-provided Java 21 / Gradle toolchain:
  ```bash
  cd application
  gradle test
  ```
- Integration coverage relies on Testcontainers (PostgreSQL 16) to exercise the full CRUD path via JPA/Flyway before packaging.
- Gradle uses the same dependencies as the Docker image, keeping local runs aligned with the eventual ECS/EC2 deployment.

### Docker image build

- Build the multi-arch container locally with BuildKit/buildx (recommended before `docker compose up`, which will rebuild if an image is missing):
  ```bash
  ./scripts/build-demo.sh
  ```
- Tags `latest` and `sha-<commit>` replicate the ECR policy enforced by Terraform.

## Runtime smoke testing

1. Bring up the local stack.

   ```bash
   docker compose up
   ```

   This starts Postgres 16 and the demo application with matching datasource environment variables.

2. In a separate terminal run the automated smoke test (requires `curl` + `jq`).

   ```bash
   ./scripts/demo-smoke.sh
   ```

   The script waits for `/healthz`, performs an authenticated CRUD cycle against `/api/v1/widgets`, and logs progress to stdout. It exits non-zero if any step fails.

3. Manual exploration: use `curl`/Postman with the header `X-Demo-Auth: local-token` to inspect behaviour or view responses in detail.

Logs appear in the compose terminal; structured JSON output mirrors what ECS/CloudWatch Logs will capture.

## Infrastructure validation

- Each stack under `infrastructure/terraform/stacks/development/<stack>` is independent. Apply them in dependency order:
  1. `core-networking`
  2. `database`
  3. `compute-ecs` / `compute-ec2`
  4. `cicd`
  5. `observability`
- Use `terraform fmt`, `terraform validate`, and (later) policy tools (`tflint`, `tfsec`) before committing.
- Stack outputs are consumed via `terraform_remote_state`, so keep `core-networking` state current before applying downstream changes.

## CI/CD alignment

When CodePipeline/CodeBuild are introduced, they will mimic the local workflow:

- Run Gradle unit + integration tests (Testcontainers).
- Build/push the Docker image to the Terraform-managed ECR repository.
- Trigger Terraform plan/apply jobs per stack (initially `compute-ecs`, `compute-ec2`, `database`).
- Record artifacts: smoke-test results, SBOMs, Terraform plans.

## Future enhancements

- Add contract tests for `/healthz` and synthetic checks for CRUD endpoints.
- Extend smoke testing: assert `/healthz` dependency states, exercise widget GET/PUT flows, verify auth failures, and (when enabled) confirm S3 metadata writes.
- Wire the smoke script into CI to validate against deployed endpoints post-release.
  EOF
