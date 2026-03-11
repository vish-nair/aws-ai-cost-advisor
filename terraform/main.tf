################################################################################
# Anthropic API Key Secret
################################################################################

resource "aws_secretsmanager_secret" "anthropic_api_key" {
  count = var.anthropic_api_key_secret_arn == null ? 1 : 0

  name                    = "aws-ai-cost-advisor/anthropic-api-key"
  description             = "Anthropic Claude API key for aws-ai-cost-advisor"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "anthropic_api_key" {
  count = var.anthropic_api_key_secret_arn == null ? 1 : 0

  secret_id     = aws_secretsmanager_secret.anthropic_api_key[0].id
  secret_string = var.anthropic_api_key
}

locals {
  api_key_secret_arn = var.anthropic_api_key_secret_arn != null ? var.anthropic_api_key_secret_arn : aws_secretsmanager_secret.anthropic_api_key[0].arn
}

################################################################################
# Storage (S3 + SNS)
################################################################################

module "storage" {
  source = "./modules/storage"

  environment       = var.environment
  report_recipients = var.report_recipients
  retention_days    = var.report_retention_days
}

################################################################################
# Lambda
################################################################################

module "lambda" {
  source = "./modules/lambda"

  environment                  = var.environment
  report_bucket_name           = module.storage.report_bucket_name
  sns_topic_arn                = module.storage.sns_topic_arn
  anthropic_api_key_secret_arn = local.api_key_secret_arn
  memory_mb                    = var.lambda_memory_mb
  timeout_seconds              = var.lambda_timeout_seconds
}

################################################################################
# Scheduler
################################################################################

module "scheduler" {
  source = "./modules/scheduler"

  environment         = var.environment
  lambda_arn          = module.lambda.lambda_arn
  lambda_name         = module.lambda.lambda_name
  schedule_expression = var.schedule_expression
}
