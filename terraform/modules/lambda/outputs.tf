output "lambda_arn" {
  value = aws_lambda_function.advisor.arn
}

output "lambda_name" {
  value = aws_lambda_function.advisor.function_name
}

output "execution_role_arn" {
  value = aws_iam_role.advisor.arn
}
