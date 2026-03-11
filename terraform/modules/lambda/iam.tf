################################################################################
# Lambda Execution Role
################################################################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "advisor" {
  name               = "aws-ai-cost-advisor-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

################################################################################
# CloudWatch Logs
################################################################################

data "aws_iam_policy_document" "logs" {
  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/aws-ai-cost-advisor-*:*"]
  }
}

resource "aws_iam_policy" "logs" {
  name   = "aws-ai-cost-advisor-logs-${var.environment}"
  policy = data.aws_iam_policy_document.logs.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.advisor.name
  policy_arn = aws_iam_policy.logs.arn
}

################################################################################
# Cost Explorer (read-only)
################################################################################

data "aws_iam_policy_document" "cost_explorer" {
  statement {
    sid    = "CostExplorerRead"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetRightsizingRecommendation",
      "ce:GetSavingsPlansRecommendation",
      "ce:GetReservationRecommendation",
    ]
    resources = ["*"] # Cost Explorer does not support resource-level restrictions
  }
}

resource "aws_iam_policy" "cost_explorer" {
  name   = "aws-ai-cost-advisor-ce-${var.environment}"
  policy = data.aws_iam_policy_document.cost_explorer.json
}

resource "aws_iam_role_policy_attachment" "cost_explorer" {
  role       = aws_iam_role.advisor.name
  policy_arn = aws_iam_policy.cost_explorer.arn
}

################################################################################
# EC2 + EBS (read-only)
################################################################################

data "aws_iam_policy_document" "ec2" {
  statement {
    sid    = "EC2Read"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
    ]
    resources = ["*"] # Describe actions require * resource
  }
  statement {
    sid    = "STSGetCallerIdentity"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ec2" {
  name   = "aws-ai-cost-advisor-ec2-${var.environment}"
  policy = data.aws_iam_policy_document.ec2.json
}

resource "aws_iam_role_policy_attachment" "ec2" {
  role       = aws_iam_role.advisor.name
  policy_arn = aws_iam_policy.ec2.arn
}

################################################################################
# RDS (read-only)
################################################################################

data "aws_iam_policy_document" "rds" {
  statement {
    sid    = "RDSRead"
    effect = "Allow"
    actions = [
      "rds:DescribeDBInstances",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "rds" {
  name   = "aws-ai-cost-advisor-rds-${var.environment}"
  policy = data.aws_iam_policy_document.rds.json
}

resource "aws_iam_role_policy_attachment" "rds" {
  role       = aws_iam_role.advisor.name
  policy_arn = aws_iam_policy.rds.arn
}

################################################################################
# CloudWatch Metrics (read-only — for CPU/RDS connection queries)
################################################################################

data "aws_iam_policy_document" "cloudwatch" {
  statement {
    sid    = "CloudWatchRead"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
    ]
    resources = ["*"] # GetMetricStatistics does not support resource-level restrictions
  }
}

resource "aws_iam_policy" "cloudwatch" {
  name   = "aws-ai-cost-advisor-cw-${var.environment}"
  policy = data.aws_iam_policy_document.cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.advisor.name
  policy_arn = aws_iam_policy.cloudwatch.arn
}

################################################################################
# S3 — Write reports
################################################################################

data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "S3WriteReports"
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::${var.report_bucket_name}/reports/*"]
  }
}

resource "aws_iam_policy" "s3" {
  name   = "aws-ai-cost-advisor-s3-${var.environment}"
  policy = data.aws_iam_policy_document.s3.json
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.advisor.name
  policy_arn = aws_iam_policy.s3.arn
}

################################################################################
# SNS — Publish notification
################################################################################

data "aws_iam_policy_document" "sns" {
  statement {
    sid    = "SNSPublish"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [var.sns_topic_arn]
  }
}

resource "aws_iam_policy" "sns" {
  name   = "aws-ai-cost-advisor-sns-${var.environment}"
  policy = data.aws_iam_policy_document.sns.json
}

resource "aws_iam_role_policy_attachment" "sns" {
  role       = aws_iam_role.advisor.name
  policy_arn = aws_iam_policy.sns.arn
}

################################################################################
# Secrets Manager — Read Anthropic API key
################################################################################

data "aws_iam_policy_document" "secrets" {
  statement {
    sid    = "ReadAnthropicKey"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [var.anthropic_api_key_secret_arn]
  }
}

resource "aws_iam_policy" "secrets" {
  name   = "aws-ai-cost-advisor-secrets-${var.environment}"
  policy = data.aws_iam_policy_document.secrets.json
}

resource "aws_iam_role_policy_attachment" "secrets" {
  role       = aws_iam_role.advisor.name
  policy_arn = aws_iam_policy.secrets.arn
}

################################################################################
# Data sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
