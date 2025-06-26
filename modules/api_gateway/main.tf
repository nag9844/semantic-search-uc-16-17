resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API Gateway for semantic search"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

# Search resource
resource "aws_api_gateway_resource" "search" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "search"
}

# Search POST method
resource "aws_api_gateway_method" "search_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.search.id
  http_method   = "POST"
  authorization = "NONE"
}

# Search OPTIONS method for CORS
resource "aws_api_gateway_method" "search_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.search.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Search POST integration
resource "aws_api_gateway_integration" "search_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.search.id
  http_method = aws_api_gateway_method.search_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.search_proxy.invoke_arn
}

# Search OPTIONS integration for CORS
resource "aws_api_gateway_integration" "search_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.search.id
  http_method = aws_api_gateway_method.search_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# Search OPTIONS method response
resource "aws_api_gateway_method_response" "search_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.search.id
  http_method = aws_api_gateway_method.search_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Search OPTIONS integration response
resource "aws_api_gateway_integration_response" "search_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.search.id
  http_method = aws_api_gateway_method.search_options.http_method
  status_code = aws_api_gateway_method_response.search_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda proxy function for search (to handle CORS properly)
resource "aws_lambda_function" "search_proxy" {
  function_name = "${var.project_name}-search-proxy"
  role         = aws_iam_role.api_lambda_role.arn
  handler      = "index.handler"
  runtime      = "python3.9"
  timeout      = 30

  filename         = data.archive_file.search_proxy.output_path
  source_code_hash = data.archive_file.search_proxy.output_base64sha256

  environment {
    variables = {
      SEARCH_LAMBDA_NAME = var.search_lambda_name
    }
  }

  tags = {
    Name        = "${var.project_name}-search-proxy"
    Environment = var.environment
  }
}

# IAM role for API Lambda
resource "aws_iam_role" "api_lambda_role" {
  name = "${var.project_name}-api-lambda-role"

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
}

resource "aws_iam_role_policy_attachment" "api_lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.api_lambda_role.name
}

resource "aws_iam_role_policy" "api_lambda_invoke" {
  name = "${var.project_name}-api-lambda-invoke"
  role = aws_iam_role.api_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.search_lambda_arn,
          var.processing_lambda_arn
        ]
      }
    ]
  })
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_integration.search_post,
    aws_api_gateway_integration.search_options
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = var.environment

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gateway_search" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_proxy.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Archive for search proxy Lambda
data "archive_file" "search_proxy" {
  type        = "zip"
  output_path = "${path.module}/search_proxy.zip"
  source_dir  = "${path.module}/src/search_proxy"
}