variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# === Lambda Configuration ===

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions for Lambda (prevents runaway costs)"
  type        = number
  default     = 100
}

variable "enable_provisioned_concurrency" {
  description = "Enable provisioned concurrency to reduce cold starts"
  type        = bool
  default     = true  # Set to true for production (has cost implications)
}

variable "provisioned_concurrency_count" {
  description = "Number of provisioned concurrent executions"
  type        = number
  default     = 2
}

variable "cache_ttl_seconds" {
  description = "Cache TTL in seconds for in-memory Lambda cache"
  type        = number
  default     = 300  # 5 minutes
}

# === API Gateway Configuration ===

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit (requests)"
  type        = number
  default     = 5000
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 2000
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]  # Restrict this in production
}

# === Monitoring & Logging ===

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}