resource "aws_s3_bucket" "widget_metadata" {
  bucket = local.widget_metadata_bucket_name

  force_destroy = false

  tags = merge(local.base_tags, {
    Component = "widget-metadata"
  })
}

resource "aws_s3_bucket_versioning" "widget_metadata" {
  bucket = aws_s3_bucket.widget_metadata.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "widget_metadata" {
  bucket                  = aws_s3_bucket.widget_metadata.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "widget_metadata" {
  bucket = aws_s3_bucket.widget_metadata.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "widget_metadata_tls" {
  statement {
    sid    = "EnforceTLS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.widget_metadata.arn,
      "${aws_s3_bucket.widget_metadata.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "widget_metadata" {
  bucket = aws_s3_bucket.widget_metadata.id
  policy = data.aws_iam_policy_document.widget_metadata_tls.json
}

output "widget_metadata_bucket_name" {
  description = "S3 bucket holding widget metadata"
  value       = aws_s3_bucket.widget_metadata.bucket
}

output "widget_metadata_bucket_arn" {
  description = "ARN of the widget metadata S3 bucket"
  value       = aws_s3_bucket.widget_metadata.arn
}
