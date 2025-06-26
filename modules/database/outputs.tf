output "endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "instance_id" {
  description = "Database instance ID"
  value       = aws_db_instance.main.id
}

output "arn" {
  description = "Database ARN"
  value       = aws_db_instance.main.arn
}