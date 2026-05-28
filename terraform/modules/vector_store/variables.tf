variable "project_name" {
  type = string
}

variable "kb_role_arn" {
  type        = string
  description = "ARN of the Bedrock KB IAM role (from foundation module)"
}

variable "account_id" {
  type        = string
  description = "AWS account ID (from foundation module)"
}

variable "region" {
  type        = string
  description = "AWS region (from foundation module)"
}

variable "embedding_dimension" {
  type    = number
  default = 1024
}

variable "python_bin" {
  type        = string
  description = "Python interpreter with boto3 (use repo .venv)"
}

variable "scripts_dir" {
  type        = string
  description = "Absolute path to the scripts/ directory"
}

variable "faq_index_name" {
  type    = string
  default = "anycompany-faq"
}

variable "prod_index_name" {
  type    = string
  default = "anycompany-products"
}
