output "collection_arn" {
  value = aws_opensearchserverless_collection.kb.arn
}

output "collection_endpoint" {
  value = aws_opensearchserverless_collection.kb.collection_endpoint
}

output "collection_id" {
  value = aws_opensearchserverless_collection.kb.id
}

output "create_indexes_id" {
  value = null_resource.create_indexes.id
}
