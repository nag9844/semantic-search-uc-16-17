variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "search_lambda_arn" {
  description = "Search Lambda ARN"
  type        = string
}

variable "search_lambda_name" {
  description = "Search Lambda name"
  type        = string
}

variable "processing_lambda_arn" {
  description = "Processing Lambda ARN"
  type        = string
}

variable "processing_lambda_name" {
  description = "Processing Lambda name"
  type        = string
}