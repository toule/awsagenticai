locals {
  aoss_collection_name = "${var.project_name}-kb"
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.project_name}-enc"
  type = "encryption"
  policy = jsonencode({
    Rules = [{
      Resource     = ["collection/${local.aoss_collection_name}"]
      ResourceType = "collection"
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.project_name}-net"
  type = "network"
  policy = jsonencode([{
    Rules = [
      { Resource = ["collection/${local.aoss_collection_name}"], ResourceType = "collection" },
      { Resource = ["collection/${local.aoss_collection_name}"], ResourceType = "dashboard" }
    ]
    AllowFromPublic = true
  }])
}

resource "aws_opensearchserverless_collection" "kb" {
  name = local.aoss_collection_name
  type = "VECTORSEARCH"
  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}

resource "aws_opensearchserverless_access_policy" "kb" {
  name = "${var.project_name}-data"
  type = "data"
  policy = jsonencode([{
    Rules = [
      {
        Resource     = ["collection/${local.aoss_collection_name}"]
        ResourceType = "collection"
        Permission   = ["aoss:*"]
      },
      {
        Resource     = ["index/${local.aoss_collection_name}/*"]
        ResourceType = "index"
        Permission   = ["aoss:*"]
      }
    ]
    Principal = [
      var.kb_role_arn,
      "arn:aws:iam::${var.account_id}:root",
    ]
  }])
}

# 인덱스 생성 (boto3 SigV4 + urllib)
resource "null_resource" "create_indexes" {
  triggers = {
    collection = aws_opensearchserverless_collection.kb.id
    script_md5 = filemd5("${var.scripts_dir}/create_aoss_indexes.py")
  }

  provisioner "local-exec" {
    command = "${var.python_bin} ${var.scripts_dir}/create_aoss_indexes.py"
    environment = {
      AOSS_ENDPOINT = aws_opensearchserverless_collection.kb.collection_endpoint
      INDEXES       = "${var.faq_index_name},${var.prod_index_name}"
      DIMENSION     = tostring(var.embedding_dimension)
      AWS_REGION    = var.region
    }
  }

  depends_on = [aws_opensearchserverless_access_policy.kb]
}
