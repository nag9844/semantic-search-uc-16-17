output "processing_lambda_arn" {
  description = "Document processing Lambda ARN"
  value       = aws_lambda_function.document_processor.arn
}

output "processing_lambda_name" {
  description = "Document processing Lambda name"
  value       = aws_lambda_function.document_processor.function_name
}

output "search_lambda_arn" {
  description = "Search Lambda ARN"
  value       = aws_lambda_function.search.arn
}

output "search_lambda_name" {
  description = "Search Lambda name"
  value       = aws_lambda_function.search.function_name
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_role.arn
}

output "s3_lambda_permission" {
  description = "S3 Lambda permission"
  value       = aws_lambda_permission.s3_invoke
}