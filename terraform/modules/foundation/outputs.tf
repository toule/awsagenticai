output "retail_bucket_arn" {
  value = aws_s3_bucket.retail.arn
}

output "retail_bucket_name" {
  value = aws_s3_bucket.retail.bucket
}

output "inventory_table_name" {
  value = aws_dynamodb_table.inventory.name
}

output "inventory_table_arn" {
  value = aws_dynamodb_table.inventory.arn
}

output "reviews_table_name" {
  value = aws_dynamodb_table.reviews.name
}

output "reviews_table_arn" {
  value = aws_dynamodb_table.reviews.arn
}

output "kb_role_arn" {
  value = aws_iam_role.kb.arn
}

output "kb_role_id" {
  value = aws_iam_role.kb.id
}

output "account_id" {
  value = local.account_id
}

output "region" {
  value = local.region
}
