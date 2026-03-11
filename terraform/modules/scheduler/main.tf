################################################################################
# IAM role for EventBridge Scheduler → Lambda
################################################################################

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "aws-ai-cost-advisor-scheduler-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "invoke_lambda" {
  statement {
    sid     = "InvokeAdvisorLambda"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [
      var.lambda_arn,
      "${var.lambda_arn}:*",
    ]
  }
}

resource "aws_iam_policy" "invoke_lambda" {
  name   = "aws-ai-cost-advisor-scheduler-invoke-${var.environment}"
  policy = data.aws_iam_policy_document.invoke_lambda.json
}

resource "aws_iam_role_policy_attachment" "invoke_lambda" {
  role       = aws_iam_role.scheduler.name
  policy_arn = aws_iam_policy.invoke_lambda.arn
}

################################################################################
# EventBridge Scheduler
################################################################################

resource "aws_scheduler_schedule" "weekly" {
  name                         = "aws-ai-cost-advisor-weekly-${var.environment}"
  description                  = "Trigger AWS AI Cost Advisor Lambda every Monday at 08:00 UTC"
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = "UTC"
  state                        = "ENABLED"

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 15 # Allow up to 15-min jitter to avoid thundering herd
  }

  target {
    arn      = var.lambda_arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{}"

    retry_policy {
      maximum_retry_attempts       = 2
      maximum_event_age_in_seconds = 3600
    }
  }
}
