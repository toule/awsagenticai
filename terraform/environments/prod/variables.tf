variable "project_name" {
  type    = string
  default = "anycompany"
}

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "coordinator_model_id" {
  type    = string
  default = "us.anthropic.claude-sonnet-4-6"
}

variable "sub_agent_model_id" {
  type    = string
  default = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "embedding_model_id" {
  type    = string
  default = "amazon.titan-embed-text-v2:0"
}

variable "embedding_dimension" {
  type    = number
  default = 1024
}

variable "python_bin" {
  type        = string
  description = "Python interpreter with boto3 (use repo .venv)"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "agentic-ai-selfhosted"
    ManagedBy   = "terraform"
    Environment = "prod"
  }
}
