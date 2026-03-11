variable "environment" {
  type = string
}

variable "lambda_arn" {
  description = "ARN of the advisor Lambda function"
  type        = string
}

variable "lambda_name" {
  description = "Name of the advisor Lambda function"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge Scheduler cron expression"
  type        = string
  default     = "cron(0 8 ? * MON *)"
}
