output "report_bucket_name" {
  description = "S3 bucket where cost reports are stored"
  value       = module.storage.report_bucket_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for cost report notifications"
  value       = module.storage.sns_topic_arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.lambda_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = module.lambda.lambda_arn
}

output "anthropic_api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Anthropic API key"
  value       = local.api_key_secret_arn
}
