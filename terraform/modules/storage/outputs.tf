output "report_bucket_name" {
  value = aws_s3_bucket.reports.bucket
}

output "report_bucket_arn" {
  value = aws_s3_bucket.reports.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.cost_reports.arn
}
