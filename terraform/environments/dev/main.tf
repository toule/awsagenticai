terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    null    = { source = "hashicorp/null",    version = "~> 3.2" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = var.tags }
}

locals {
  # Paths relative to repo root — adjust if terraform/ is moved
  repo_root     = abspath("${path.module}/../../..")
  scripts_dir   = "${local.repo_root}/scripts"
  seed_data_dir = "${local.repo_root}/seed-data"
  build_dir     = "${path.module}/build"
}

# ───── foundation ────────────────────────────────────────────────────
module "foundation" {
  source = "../../modules/foundation"

  project_name       = var.project_name
  embedding_model_id = var.embedding_model_id
  python_bin         = var.python_bin
  scripts_dir        = local.scripts_dir
  seed_data_dir      = local.seed_data_dir
}

# ───── vector_store ──────────────────────────────────────────────────
module "vector_store" {
  source = "../../modules/vector_store"

  project_name        = var.project_name
  kb_role_arn         = module.foundation.kb_role_arn
  account_id          = module.foundation.account_id
  region              = module.foundation.region
  embedding_dimension = var.embedding_dimension
  python_bin          = var.python_bin
  scripts_dir         = local.scripts_dir

  depends_on = [module.foundation]
}

# ───── knowledge_base ────────────────────────────────────────────────
module "knowledge_base" {
  source = "../../modules/knowledge_base"

  project_name       = var.project_name
  region             = module.foundation.region
  kb_role_arn        = module.foundation.kb_role_arn
  retail_bucket_arn  = module.foundation.retail_bucket_arn
  collection_arn     = module.vector_store.collection_arn
  create_indexes_id  = module.vector_store.create_indexes_id
  embedding_model_id = var.embedding_model_id

  depends_on = [module.vector_store]
}

# ───── gateway ────────────────────────────────────────────────────────
module "gateway" {
  source = "../../modules/gateway"

  project_name       = var.project_name
  region             = module.foundation.region
  account_id         = module.foundation.account_id
  reviews_table_name = module.foundation.reviews_table_name
  reviews_table_arn  = module.foundation.reviews_table_arn
  build_dir          = local.build_dir

  depends_on = [module.foundation]
}

# ───── config ────────────────────────────────────────────────────────
module "config" {
  source = "../../modules/config"

  coordinator_model_id        = var.coordinator_model_id
  sub_agent_model_id          = var.sub_agent_model_id
  faq_kb_id                   = module.knowledge_base.faq_kb_id
  products_kb_id              = module.knowledge_base.products_kb_id
  agentcore_gateway_role_name = module.gateway.agentcore_gateway_role_name
  cognito_user_pool_id        = module.gateway.cognito_user_pool_id
  cognito_user_pool_domain    = module.gateway.cognito_user_pool_domain
  cognito_client_id           = module.gateway.cognito_client_id
  region                      = module.foundation.region

  depends_on = [module.knowledge_base, module.gateway]
}

# ───── outputs ────────────────────────────────────────────────────────
output "retail_bucket"              { value = module.foundation.retail_bucket_name }
output "faq_kb_id"                  { value = module.knowledge_base.faq_kb_id }
output "products_kb_id"             { value = module.knowledge_base.products_kb_id }
output "lambda_reviews_arn"         { value = module.gateway.lambda_reviews_arn }
output "agentcore_gateway_role_arn" { value = module.gateway.agentcore_gateway_role_arn }
output "cognito_client_id"          { value = module.gateway.cognito_client_id }
output "cognito_discovery_url"      { value = module.gateway.cognito_discovery_url }
output "cognito_token_endpoint"     { value = module.gateway.cognito_token_endpoint }
output "cognito_secret_arn"         { value = module.gateway.cognito_secret_arn }
output "aoss_collection_endpoint"   { value = module.vector_store.collection_endpoint }
