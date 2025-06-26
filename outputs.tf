output "s3_bucket_name" {
  description = "Name of the S3 bucket for documents"
  value       = aws_s3_bucket.documents.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.documents.arn
}

output "database_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.database.endpoint
}

output "database_port" {
  description = "RDS PostgreSQL port"
  value       = module.database.port
}

output "api_gateway_url" {
  description = "API Gateway URL for search endpoints"
  value       = module.api_gateway.api_url
}

output "api_gateway_stage_url" {
  description = "API Gateway stage URL"
  value       = module.api_gateway.stage_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "document_processor_lambda_arn" {
  description = "Document processor Lambda ARN"
  value       = module.lambda_processing.processing_lambda_arn
}

output "search_lambda_arn" {
  description = "Search Lambda ARN"
  value       = module.lambda_processing.search_lambda_arn
}