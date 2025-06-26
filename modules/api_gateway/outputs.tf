output "api_url" {
  description = "API Gateway URL"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "stage_url" {
  description = "API Gateway stage URL"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}"
}

output "api_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.main.id
}

data "aws_region" "current" {}