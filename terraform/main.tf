provider "aws" {
  region = var.aws_region
}

# --- DynamoDB Table ---
resource "aws_dynamodb_table" "llm_scores" {
  name           = "llm_scores"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "model_name"

  attribute {
    name = "model_name"
    type = "S"
  }
}

# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_role" {
  name = "llm_scores_lambda_role"

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

# Policy to allow logging and DynamoDB access
resource "aws_iam_role_policy" "lambda_policy" {
  name = "llm_scores_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        # == More restrictive - only for this Lambda function ==
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${aws_lambda_function.llm_service.function_name}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        # == More restrictive - only for this specific table ==
        Resource = aws_dynamodb_table.llm_scores.arn
      }
    ]
  })
}

# --- Lambda Function ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../src"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "llm_service" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "llm_scores_service"
  role             = aws_iam_role.lambda_role.arn
  handler          = "app.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 10
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      TABLE_NAME        = aws_dynamodb_table.llm_scores.name
      CACHE_TTL_SECONDS = var.cache_ttl_seconds
    }
  }

  # Reserved concurrent executions (prevents runaway costs)
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  tags = {
    Environment = var.environment
    Service     = "llm-scores"
  }
}

# === OPTIMIZATION: Provisioned Concurrency ===
# Keeps Lambda instances warm to eliminate cold starts
resource "aws_lambda_provisioned_concurrency_config" "llm_service_provisioned" {
  count                             = var.enable_provisioned_concurrency ? 1 : 0
  function_name                     = aws_lambda_function.llm_service.function_name
  provisioned_concurrent_executions = var.provisioned_concurrency_count
  qualifier                         = aws_lambda_function.llm_service.version
}

# === Publish a new version for provisioned concurrency ===
resource "aws_lambda_alias" "llm_service_live" {
  name             = "live"
  description      = "Live alias for llm_service"
  function_name    = aws_lambda_function.llm_service.function_name
  function_version = aws_lambda_function.llm_service.version
}

# === CloudWatch Log Group with Retention ===
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.llm_service.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    Service     = "llm-scores"
  }
}

# --- API Gateway (HTTP API) ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "llm_scores_api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Environment = var.environment
    Service     = "llm-scores"
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  # === Enable Access Logging ===
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  # === OPTIMIZATION: Throttling Settings ===
  default_route_settings {
    throttling_burst_limit = var.api_throttle_burst_limit
    throttling_rate_limit  = var.api_throttle_rate_limit
  }

  tags = {
    Environment = var.environment
    Service     = "llm-scores"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.http_api.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    Service     = "llm-scores"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.llm_service.invoke_arn
  
  # Timeout configuration
  timeout_milliseconds = 10000
}

resource "aws_apigatewayv2_route" "get_llms" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /llms"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Health check endpoint
resource "aws_apigatewayv2_route" "health_check" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.llm_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}