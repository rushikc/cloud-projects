resource "aws_dynamodb_table" "data" {
  name           = "${var.project_name}-data"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "auth" {
  name           = "${var.project_name}-auth"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "token"

  attribute {
    name = "token"
    type = "S"
  }
}
