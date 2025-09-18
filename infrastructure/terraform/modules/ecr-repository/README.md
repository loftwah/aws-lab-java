# ECR Repository Module

Creates an Amazon ECR repository with optional tag immutability, on-push scanning, and a simple lifecycle policy retaining the most recent images.

## Inputs

- `name` (string, required): Repository name.
- `image_tag_mutability` (string, default `IMMUTABLE`): Tag mutability (`IMMUTABLE` or `MUTABLE`).
- `scan_on_push` (bool, default `true`): Enable ECR scanning on image push.
- `lifecycle_keep_count` (number, default `10`): Number of most recent images to keep before expiring older ones.
- `encryption_type` (string, default `AES256`): Encryption type (`AES256` or `KMS`).
- `kms_key_arn` (string, default empty): KMS key ARN when `encryption_type` is `KMS`.

## Outputs

- `repository_name`
- `repository_arn`
- `repository_url`

Tagging is inherited from the parent provider via `default_tags`.
