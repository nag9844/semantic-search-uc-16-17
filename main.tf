terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Random suffix for unique resource naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket for document storage
resource "aws_s3_bucket" "documents" {
  bucket = "${var.project_name}-documents-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-documents"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project_name       = var.project_name
  environment        = var.environment
  cidr_block         = var.vpc_cidr
  availability_zones = var.availability_zones
}

# Database Module
module "database" {
  source = "./modules/database"
  
  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  security_groups = [module.vpc.database_security_group_id]
  
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  database_name     = var.database_name
  master_username   = var.db_master_username
  master_password   = var.db_master_password
}

# Lambda Processing Module
module "lambda_processing" {
  source = "./modules/lambda"
  
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.lambda_security_group_id]
  
  s3_bucket_name = aws_s3_bucket.documents.bucket
  database_host  = module.database.endpoint
  database_name  = var.database_name
  database_user  = var.db_master_username
  database_pass  = var.db_master_password
  openai_api_key = var.openai_api_key
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api_gateway"
  
  project_name           = var.project_name
  environment            = var.environment
  search_lambda_arn      = module.lambda_processing.search_lambda_arn
  search_lambda_name     = module.lambda_processing.search_lambda_name
  processing_lambda_arn  = module.lambda_processing.processing_lambda_arn
  processing_lambda_name = module.lambda_processing.processing_lambda_name
}

# S3 Event notification to trigger processing
resource "aws_s3_bucket_notification" "document_upload" {
  bucket = aws_s3_bucket.documents.id

  lambda_function {
    lambda_function_arn = module.lambda_processing.processing_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "documents/"
    filter_suffix       = ".pdf"
  }

  depends_on = [module.lambda_processing.s3_lambda_permission]
}