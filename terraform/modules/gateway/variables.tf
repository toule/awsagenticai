variable "project_name" {
  type = string
}

variable "region" {
  type        = string
  description = "AWS region (from foundation module)"
}

variable "account_id" {
  type        = string
  description = "AWS account ID (from foundation module)"
}

variable "reviews_table_name" {
  type        = string
  description = "DynamoDB reviews table name (from foundation module)"
}

variable "reviews_table_arn" {
  type        = string
  description = "DynamoDB reviews table ARN (from foundation module)"
}

variable "build_dir" {
  type        = string
  description = "Absolute path to a writable directory for Lambda ZIP artifacts"
  default     = "/tmp/awsagenticai/terraform/build"
}
