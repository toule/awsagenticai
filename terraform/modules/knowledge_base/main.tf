locals {
  aoss_collection_name = "${var.project_name}-kb"
}

# ───── Bedrock Knowledge Base: FAQ ───────────────────────────────────
resource "aws_bedrockagent_knowledge_base" "faq" {
  name     = var.faq_kb_name
  role_arn = var.kb_role_arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/${var.embedding_model_id}"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = var.collection_arn
      vector_index_name = var.faq_index_name
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "faq" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.faq.id
  name              = "faq-files-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = var.retail_bucket_arn
      inclusion_prefixes = ["anycompany_profile/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }
}

# ───── Bedrock Knowledge Base: Products ──────────────────────────────
resource "aws_bedrockagent_knowledge_base" "products" {
  name     = var.products_kb_name
  role_arn = var.kb_role_arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/${var.embedding_model_id}"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = var.collection_arn
      vector_index_name = var.prod_index_name
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "products" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.products.id
  name              = "product-files-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = var.retail_bucket_arn
      inclusion_prefixes = ["anycompany_products/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "NONE"
    }
  }
}

# ───── KB ingestion ──────────────────────────────────────────────────
resource "null_resource" "kb_ingest_faq" {
  triggers = {
    kb = aws_bedrockagent_knowledge_base.faq.id
    ds = aws_bedrockagent_data_source.faq.data_source_id
  }
  provisioner "local-exec" {
    command = "aws bedrock-agent start-ingestion-job --knowledge-base-id ${aws_bedrockagent_knowledge_base.faq.id} --data-source-id ${aws_bedrockagent_data_source.faq.data_source_id} --region ${var.region}"
  }
  depends_on = [aws_bedrockagent_data_source.faq]
}

resource "null_resource" "kb_ingest_products" {
  triggers = {
    kb = aws_bedrockagent_knowledge_base.products.id
    ds = aws_bedrockagent_data_source.products.data_source_id
  }
  provisioner "local-exec" {
    command = "aws bedrock-agent start-ingestion-job --knowledge-base-id ${aws_bedrockagent_knowledge_base.products.id} --data-source-id ${aws_bedrockagent_data_source.products.data_source_id} --region ${var.region}"
  }
  depends_on = [aws_bedrockagent_data_source.products]
}
