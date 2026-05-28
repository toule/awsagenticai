resource "aws_ssm_parameter" "coordinator_model_id" {
  name      = "coordinator_model_id"
  type      = "String"
  value     = var.coordinator_model_id
  overwrite = true
}

resource "aws_ssm_parameter" "agent_model_id" {
  name      = "agent_model_id"
  type      = "String"
  value     = var.sub_agent_model_id
  overwrite = true
}

resource "aws_ssm_parameter" "faq_kb_id" {
  name      = "faq_kb_id"
  type      = "String"
  value     = var.faq_kb_id
  overwrite = true
}

resource "aws_ssm_parameter" "products_kb_id" {
  name      = "product_search_kb_id"
  type      = "String"
  value     = var.products_kb_id
  overwrite = true
}

resource "aws_ssm_parameter" "agentcore_gateway_role_name" {
  name      = "agentcore_gateway_role_name"
  type      = "String"
  value     = var.agentcore_gateway_role_name
  overwrite = true
}

resource "aws_ssm_parameter" "cognito_discovery_url" {
  name      = "cognito_discovery_url"
  type      = "String"
  value     = "https://cognito-idp.${var.region}.amazonaws.com/${var.cognito_user_pool_id}/.well-known/openid-configuration"
  overwrite = true
}

resource "aws_ssm_parameter" "cognito_token_endpoint" {
  name      = "cognito_token_endpoint"
  type      = "String"
  value     = "https://${var.cognito_user_pool_domain}.auth.${var.region}.amazoncognito.com/oauth2/token"
  overwrite = true
}

resource "aws_ssm_parameter" "cognito_client_id" {
  name      = "cognito_client_id"
  type      = "String"
  value     = var.cognito_client_id
  overwrite = true
}

resource "aws_ssm_parameter" "agentcore_gateway_url" {
  name      = "anycomp_prod_reviews_mcp_server_url"
  type      = "String"
  value     = "PENDING_GATEWAY_CREATION"
  overwrite = true
  lifecycle {
    ignore_changes = [value]
  }
}
