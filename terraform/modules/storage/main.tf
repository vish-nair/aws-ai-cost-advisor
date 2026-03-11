################################################################################
# S3 — Report Bucket
################################################################################

resource "aws_s3_bucket" "reports" {
  bucket        = "aws-ai-cost-advisor-reports-${data.aws_caller_identity.current.account_id}-${var.environment}"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    id     = "archive-old-reports"
    status = "Enabled"
    transition {
      days          = var.retention_days
      storage_class = "GLACIER"
    }
  }
}

################################################################################
# SNS — Cost Report Notifications
################################################################################

resource "aws_sns_topic" "cost_reports" {
  name              = "aws-ai-cost-advisor-${var.environment}"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.report_recipients)

  topic_arn = aws_sns_topic.cost_reports.arn
  protocol  = "email"
  endpoint  = each.value
}

################################################################################
# Data
################################################################################

data "aws_caller_identity" "current" {}
