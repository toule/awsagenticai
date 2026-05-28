variable "coordinator_model_id" {
  type = string
}

variable "sub_agent_model_id" {
  type = string
}

variable "faq_kb_id" {
  type        = string
  description = "FAQ KB ID (from knowledge_base module)"
}

variable "products_kb_id" {
  type        = string
  description = "Products KB ID (from knowledge_base module)"
}

variable "agentcore_gateway_role_name" {
  type        = string
  description = "AgentCore Gateway IAM role name (from gateway module)"
}

variable "cognito_user_pool_id" {
  type        = string
  description = "Cognito User Pool ID (from gateway module)"
}

variable "cognito_user_pool_domain" {
  type        = string
  description = "Cognito User Pool domain prefix (from gateway module)"
}

variable "cognito_client_id" {
  type        = string
  description = "Cognito M2M client ID (from gateway module)"
}

variable "region" {
  type        = string
  description = "AWS region (from foundation module)"
}
