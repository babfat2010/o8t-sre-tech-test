output "api_url" {
  description = "The URL of the API Gateway"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.llm_scores.name
}
