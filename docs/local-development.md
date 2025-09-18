# Local Development

These steps assume an Apple Silicon Mac (M-series including M4) running macOS Sonoma or later. Adjust package manager commands as needed for your setup.

## Prerequisites

- [mise](https://mise.jdx.dev/) (tool version manager)
- Docker Desktop (or an alternative Docker Engine) with BuildKit enabled
- Homebrew (used for installing tooling below)
- Gradle 8.7+ (`brew install gradle`)
- [`jq`](https://stedolan.github.io/jq/) (used by the smoke-test script)

Install the base tooling:

```bash
# mise
brew install mise

# Docker Desktop (optional if you already have it)
brew install --cask docker

# Gradle CLI for local builds
brew install gradle
```

Launch Docker Desktop at least once so the daemon is available for local builds.

## Runtime toolchain

The repository includes a `.mise.toml` pinning the tool versions used across labs:

```toml
[tools]
java = "21.0.2"
terraform = "1.13.0"
gradle = "8.7"
```

Install and activate them with:

```bash
mise install
mise use
```

This ensures:

- **Java 21** is available for VS Code/Cursor Java tooling and local Gradle runs.
- **Terraform 1.13.0** matches the version required by the infrastructure code.
- **Gradle 8.7** mirrors the version used by the Docker build image, keeping wrapper behaviour consistent. If you installed Gradle via Homebrew, make sure it stays on the pinned version.

> **Tip:** Add `eval "$(mise activate zsh)"` to your shell profile (e.g. `~/.zshrc`) so the tools are on your PATH in new terminals.

Verify the versions:

```bash
java -version
terraform version
gradle --version
```

## Running the demo application locally

1. Build the container image (uses BuildKit/buildx under the hood). This catches compile errors before Compose rebuilds the image:
   ```bash
   ./scripts/build-demo.sh
   ```
2. (Optional) Run the integration test suite locally:
   ```bash
   (cd application && gradle test)
   ```
3. Start the Docker Compose stack (PostgreSQL + demo app):
   ```bash
   docker compose up
   ```
4. Visit `http://localhost:8080/` for the landing page and `http://localhost:8080/healthz` for the health endpoint.
5. When calling the CRUD APIs manually, include the header `X-Demo-Auth: local-token` (for example with `curl`). Secrets Manager/SSM integration is disabled locally unless you export the relevant `AWS_*` environment variables.
6. In a separate terminal, run the automated smoke test (requires `curl` + `jq`):
   ```bash
   ./scripts/demo-smoke.sh
   ```
   The script waits for `/healthz`, performs CRUD operations using the `local-token`, and prints progress to the terminal.

Stop the stack with `docker compose down`. Data persists in the `postgres-data` volume between runs.

## Working with Terraform

Run Terraform from within the environment directories, relying on the `.mise.toml` managed version:

```bash
terraform -chdir=infrastructure/terraform/state-bootstrap init
terraform -chdir=infrastructure/terraform/state-bootstrap apply
```

Then initialise each development stack (start with core networking):

```bash
terraform -chdir=infrastructure/terraform/stacks/development/core-networking init -migrate-state
```

Run other stacks from their own directories (e.g. `database`, `compute-ecs`) when you are ready. Each uses `terraform_remote_state` to read networking outputs, so keep the `core-networking` stack up to date first.

## VS Code / Cursor setup

- Install the “Extension Pack for Java”.
- In your workspace settings, point `java.configuration.runtimes` to the mise-managed JDK if needed:
  ```json
  {
    "java.configuration.runtimes": [
      {
        "name": "JavaSE-21",
        "path": "~/.local/share/mise/installs/java/21.0.2"
      }
    ]
  }
  ```
- Enable the Docker and Terraform extensions for best results when working across code and infrastructure labs.

With these steps the repo can be built, tested, and iterated locally before any AWS resources are touched.
