################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "advisor" {
  name              = "/aws/lambda/aws-ai-cost-advisor-${var.environment}"
  retention_in_days = 30
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "advisor" {
  function_name = "aws-ai-cost-advisor-${var.environment}"
  description   = "Weekly AWS cost analysis powered by Claude AI"
  role          = aws_iam_role.advisor.arn

  # Deployment package — uploaded by CI/CD via S3 or direct zip
  filename         = var.deployment_package_path
  source_code_hash = filebase64sha256(var.deployment_package_path)
  handler          = "advisor.handler"
  runtime          = "python3.12"

  memory_size = var.memory_mb
  timeout     = var.timeout_seconds

  environment {
    variables = {
      REPORT_BUCKET                = var.report_bucket_name
      SNS_TOPIC_ARN                = var.sns_topic_arn
      ANTHROPIC_API_KEY_SECRET_ARN = var.anthropic_api_key_secret_arn
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.advisor.name
  }

  depends_on = [aws_cloudwatch_log_group.advisor]
}
