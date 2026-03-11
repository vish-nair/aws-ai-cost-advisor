variable "environment" {
  type = string
}

variable "report_bucket_name" {
  description = "Name of the S3 bucket where reports are saved"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for report notifications"
  type        = string
}

variable "anthropic_api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Anthropic API key"
  type        = string
}

variable "memory_mb" {
  type    = number
  default = 512
}

variable "timeout_seconds" {
  type    = number
  default = 900
}

variable "deployment_package_path" {
  description = "Path to the Lambda deployment zip. Defaults to a pre-built package in the repo."
  type        = string
  default     = "../../dist/advisor.zip"
}
