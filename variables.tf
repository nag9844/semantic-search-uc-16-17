variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "semantic-search"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "semantic_search"
}

variable "db_master_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "db_master_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default = "demo#4317"
}

variable "openai_api_key" {
  description = "OpenAI API key for embeddings"
  type        = string
  sensitive   = true
  default = "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"
}