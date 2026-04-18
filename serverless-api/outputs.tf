output "api_url" {
  description = "Base invoke URL for the REST API (stage prod)."
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "data_endpoint_get" {
  description = "GET /data with query id=..."
  value       = "${aws_api_gateway_stage.prod.invoke_url}/data?id=<id>"
}

output "data_endpoint_post" {
  description = "POST /data with JSON body { \"id\": \"...\", \"attributes\": { ... } }"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/data"
}

output "dynamodb_data_table_name" {
  value = aws_dynamodb_table.data.name
}

output "dynamodb_auth_table_name" {
  value = aws_dynamodb_table.auth.name
}
