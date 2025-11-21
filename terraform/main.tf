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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
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

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.llm_scores.name
    }
  }
}

# --- API Gateway (HTTP API) ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "llm_scores_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.llm_service.invoke_arn
}

resource "aws_apigatewayv2_route" "get_llms" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /llms"
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
