output "lambda_reviews_arn" {
  value = aws_lambda_function.retrieve_product_reviews.arn
}

output "lambda_reviews_function_name" {
  value = aws_lambda_function.retrieve_product_reviews.function_name
}

output "agentcore_gateway_role_arn" {
  value = aws_iam_role.agentcore_gateway.arn
}

output "agentcore_gateway_role_name" {
  value = aws_iam_role.agentcore_gateway.name
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_domain" {
  value = aws_cognito_user_pool_domain.main.domain
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.m2m.id
}

output "cognito_discovery_url" {
  value = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.main.id}/.well-known/openid-configuration"
}

output "cognito_token_endpoint" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com/oauth2/token"
}

output "cognito_secret_arn" {
  value = aws_secretsmanager_secret.cognito_client.arn
}
