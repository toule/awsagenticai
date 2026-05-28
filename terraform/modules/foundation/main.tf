data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id         = data.aws_caller_identity.current.account_id
  region             = data.aws_region.current.name
  retail_bucket_name = "${var.project_name}-retail-${local.account_id}-${local.region}"
  inventory_table    = "anycompany_product_inventory"
  reviews_table      = "anycompany_product_reviews"
}

# ───── S3 ────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "retail" {
  bucket        = local.retail_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "retail" {
  bucket = aws_s3_bucket.retail.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "retail" {
  bucket                  = aws_s3_bucket.retail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ───── DynamoDB ──────────────────────────────────────────────────────
resource "aws_dynamodb_table" "inventory" {
  name         = local.inventory_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"
  attribute {
    name = "product_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "reviews" {
  name         = local.reviews_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"
  attribute {
    name = "product_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}

# ───── IAM — KB role ─────────────────────────────────────────────────
data "aws_iam_policy_document" "kb_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "kb" {
  name               = "AmazonBedrockExecutionRoleForKnowledgeBase-${var.project_name}"
  assume_role_policy = data.aws_iam_policy_document.kb_assume.json
}

data "aws_iam_policy_document" "kb_policy" {
  statement {
    sid       = "S3"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.retail.arn, "${aws_s3_bucket.retail.arn}/*"]
  }
  statement {
    sid     = "BedrockEmbedding"
    effect  = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:aws:bedrock:${local.region}::foundation-model/${var.embedding_model_id}"
    ]
  }
  statement {
    sid       = "AOSS"
    effect    = "Allow"
    actions   = ["aoss:APIAccessAll"]
    # reference aoss collection arn via variable (passed from root after vector_store is created)
    resources = ["arn:aws:aoss:${local.region}:${local.account_id}:collection/*"]
  }
}

resource "aws_iam_role_policy" "kb" {
  role   = aws_iam_role.kb.id
  policy = data.aws_iam_policy_document.kb_policy.json
}

# ───── Seed: S3 sync ─────────────────────────────────────────────────
resource "null_resource" "s3_seed" {
  triggers = {
    bucket   = aws_s3_bucket.retail.bucket
    seed_md5 = filemd5("${var.seed_data_dir}/MANIFEST.txt")
  }

  provisioner "local-exec" {
    command = "aws s3 sync ${var.seed_data_dir}/ s3://${aws_s3_bucket.retail.bucket}/ --exclude 'MANIFEST.txt' --exclude '*.DS_Store' --region ${local.region}"
  }

  depends_on = [aws_s3_bucket.retail]
}

# ───── Seed: DynamoDB ────────────────────────────────────────────────
resource "null_resource" "ddb_seed_inventory" {
  triggers = { table = aws_dynamodb_table.inventory.name }
  provisioner "local-exec" {
    command = "${var.python_bin} ${var.scripts_dir}/load_ddb.py inventory ${aws_dynamodb_table.inventory.name}"
  }
  depends_on = [aws_dynamodb_table.inventory]
}

resource "null_resource" "ddb_seed_reviews" {
  triggers = { table = aws_dynamodb_table.reviews.name }
  provisioner "local-exec" {
    command = "${var.python_bin} ${var.scripts_dir}/load_ddb.py reviews ${aws_dynamodb_table.reviews.name}"
  }
  depends_on = [aws_dynamodb_table.reviews]
}
