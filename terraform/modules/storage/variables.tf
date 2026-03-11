variable "environment" {
  type = string
}

variable "report_recipients" {
  description = "Email addresses to subscribe to the SNS topic"
  type        = list(string)
}

variable "retention_days" {
  description = "Days before reports are transitioned to Glacier"
  type        = number
  default     = 90
}
