# state_bucket module

Creates an encrypted, versioned Amazon S3 bucket suitable for storing Terraform state files. Public access is blocked by default and lifecycle policies can optionally transition old versions to Glacier to control costs.

## Inputs

- `bucket_name` (string, required): Globally unique name for the bucket.
- `force_destroy` (bool, default `false`): Allows Terraform to remove the bucket even when objects remain.
- `block_public_access` (bool, default `true`): Applies AWS' full public access block.
- `object_lifecycle_days` (number, default `null`): When set, transitions non-current object versions to Glacier after this many days.

## Outputs

- `bucket_id`: Bucket name.
- `bucket_arn`: Bucket ARN.
