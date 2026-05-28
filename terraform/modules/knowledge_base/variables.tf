variable "project_name" {
  type = string
}

variable "region" {
  type        = string
  description = "AWS region (from foundation module)"
}

variable "kb_role_arn" {
  type        = string
  description = "ARN of the Bedrock KB IAM role (from foundation module)"
}

variable "retail_bucket_arn" {
  type        = string
  description = "ARN of the retail S3 bucket (from foundation module)"
}

variable "collection_arn" {
  type        = string
  description = "ARN of the AOSS collection (from vector_store module)"
}

variable "create_indexes_id" {
  type        = string
  description = "ID of the null_resource.create_indexes (from vector_store module) — used for depends_on ordering"
}

variable "embedding_model_id" {
  type = string
}

variable "faq_index_name" {
  type    = string
  default = "anycompany-faq"
}

variable "prod_index_name" {
  type    = string
  default = "anycompany-products"
}

variable "faq_kb_name" {
  type    = string
  default = "faq-knowledge-base"
}

variable "products_kb_name" {
  type    = string
  default = "anycompany-products-kb"
}
