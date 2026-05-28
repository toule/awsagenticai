output "ssm_coordinator_model_id_name" {
  value = aws_ssm_parameter.coordinator_model_id.name
}

output "ssm_faq_kb_id_name" {
  value = aws_ssm_parameter.faq_kb_id.name
}

output "ssm_products_kb_id_name" {
  value = aws_ssm_parameter.products_kb_id.name
}

output "ssm_agentcore_gateway_url_name" {
  value = aws_ssm_parameter.agentcore_gateway_url.name
}
