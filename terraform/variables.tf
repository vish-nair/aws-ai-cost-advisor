variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (e.g. prod, staging)"
  type        = string
  default     = "prod"
}

variable "report_recipients" {
  description = "List of email addresses to subscribe to the SNS cost report topic"
  type        = list(string)
}

variable "schedule_expression" {
  description = "EventBridge Scheduler cron expression for weekly runs"
  type        = string
  default     = "cron(0 8 ? * MON *)" # Every Monday at 08:00 UTC
}

variable "anthropic_api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Anthropic API key. Leave null to create a new secret."
  type        = string
  default     = null
}

variable "anthropic_api_key" {
  description = "Anthropic API key value. Only used when anthropic_api_key_secret_arn is null (creates a new secret)."
  type        = string
  default     = null
  sensitive   = true
}

variable "lambda_memory_mb" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 900 # 15 minutes — Claude streaming can take a while
}

variable "report_retention_days" {
  description = "S3 lifecycle rule: days before reports are moved to Glacier"
  type        = number
  default     = 90
}
