# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
  }
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Lambda VPC access policy
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# S3 access policy for Lambda
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}"
      }
    ]
  })
}

# SSM Parameter access for Lambda
resource "aws_iam_role_policy" "lambda_ssm" {
  name = "${var.project_name}-lambda-ssm-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

# Lambda Layer for dependencies
resource "aws_lambda_layer_version" "dependencies" {
  filename         = data.archive_file.lambda_layer.output_path
  layer_name       = "${var.project_name}-dependencies"
  source_code_hash = data.archive_file.lambda_layer.output_base64sha256

  compatible_runtimes = ["python3.9"]

  depends_on = [data.archive_file.lambda_layer]
}

# Document processing Lambda function
resource "aws_lambda_function" "document_processor" {
  filename         = data.archive_file.document_processor.output_path
  function_name    = "${var.project_name}-document-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 1024
  source_code_hash = data.archive_file.document_processor.output_base64sha256

  layers = [aws_lambda_layer_version.dependencies.arn]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      DATABASE_HOST  = var.database_host
      DATABASE_NAME  = var.database_name
      DATABASE_USER  = var.database_user
      DATABASE_PASS  = var.database_pass
      S3_BUCKET      = var.s3_bucket_name
      OPENAI_API_KEY = var.openai_api_key
      PROJECT_NAME   = var.project_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.document_processor
  ]

  tags = {
    Name        = "${var.project_name}-document-processor"
    Environment = var.environment
  }
}

# Search Lambda function
resource "aws_lambda_function" "search" {
  filename         = data.archive_file.search.output_path
  function_name    = "${var.project_name}-search"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 512
  source_code_hash = data.archive_file.search.output_base64sha256

  layers = [aws_lambda_layer_version.dependencies.arn]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      DATABASE_HOST  = var.database_host
      DATABASE_NAME  = var.database_name
      DATABASE_USER  = var.database_user
      DATABASE_PASS  = var.database_pass
      OPENAI_API_KEY = var.openai_api_key
      PROJECT_NAME   = var.project_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.search
  ]

  tags = {
    Name        = "${var.project_name}-search"
    Environment = var.environment
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "document_processor" {
  name              = "/aws/lambda/${var.project_name}-document-processor"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-document-processor-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "search" {
  name              = "/aws/lambda/${var.project_name}-search"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-search-logs"
    Environment = var.environment
  }
}

# S3 permission for Lambda
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.document_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.s3_bucket_name}"
}

# Archive files for Lambda functions
data "archive_file" "lambda_layer" {
  type        = "zip"
  output_path = "${path.module}/lambda_layer.zip"
  source_dir  = "${path.module}/src/layer"
}

data "archive_file" "document_processor" {
  type        = "zip"
  output_path = "${path.module}/document_processor.zip"
  source_dir  = "${path.module}/src/document_processor"
}

data "archive_file" "search" {
  type        = "zip"
  output_path = "${path.module}/search.zip"
  source_dir  = "${path.module}/src/search"
}