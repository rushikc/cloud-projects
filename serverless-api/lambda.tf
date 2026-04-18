locals {
  authorizer_fn_name = "${var.project_name}-authorizer"
  read_fn_name       = "${var.project_name}-read"
  write_fn_name      = "${var.project_name}-write"
}

# --- Install production deps before zipping ---

resource "null_resource" "npm_install_authorizer" {
  triggers = {
    package_json = filemd5("${path.module}/src/authorizer/package.json")
  }

  provisioner "local-exec" {
    command     = "npm install --omit=dev"
    working_dir = "${path.module}/src/authorizer"
  }
}

resource "null_resource" "npm_install_read" {
  triggers = {
    package_json = filemd5("${path.module}/src/read/package.json")
  }

  provisioner "local-exec" {
    command     = "npm install --omit=dev"
    working_dir = "${path.module}/src/read"
  }
}

resource "null_resource" "npm_install_write" {
  triggers = {
    package_json = filemd5("${path.module}/src/write/package.json")
  }

  provisioner "local-exec" {
    command     = "npm install --omit=dev"
    working_dir = "${path.module}/src/write"
  }
}

data "archive_file" "authorizer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/authorizer"
  output_path = "${path.module}/build/authorizer.zip"

  depends_on = [null_resource.npm_install_authorizer]
}

data "archive_file" "read_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/read"
  output_path = "${path.module}/build/read.zip"

  depends_on = [null_resource.npm_install_read]
}

data "archive_file" "write_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/write"
  output_path = "${path.module}/build/write.zip"

  depends_on = [null_resource.npm_install_write]
}

# --- CloudWatch log groups (predictable names for IAM) ---

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/${local.authorizer_fn_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "read" {
  name              = "/aws/lambda/${local.read_fn_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "write" {
  name              = "/aws/lambda/${local.write_fn_name}"
  retention_in_days = 7
}

# --- IAM: authorizer ---

resource "aws_iam_role" "authorizer" {
  name = "${var.project_name}-authorizer-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "authorizer" {
  name = "${var.project_name}-authorizer-policy"
  role = aws_iam_role.authorizer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AuthTableRead"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.auth.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.authorizer.arn,
          "${aws_cloudwatch_log_group.authorizer.arn}:*"
        ]
      }
    ]
  })
}

# --- IAM: read ---

resource "aws_iam_role" "read" {
  name = "${var.project_name}-read-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "read" {
  name = "${var.project_name}-read-policy"
  role = aws_iam_role.read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DataTableRead"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.data.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.read.arn,
          "${aws_cloudwatch_log_group.read.arn}:*"
        ]
      }
    ]
  })
}

# --- IAM: write ---

resource "aws_iam_role" "write" {
  name = "${var.project_name}-write-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "write" {
  name = "${var.project_name}-write-policy"
  role = aws_iam_role.write.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DataTableWrite"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.data.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.write.arn,
          "${aws_cloudwatch_log_group.write.arn}:*"
        ]
      }
    ]
  })
}

# --- Lambda functions ---

resource "aws_lambda_function" "authorizer" {
  function_name = local.authorizer_fn_name
  role          = aws_iam_role.authorizer.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 5

  filename         = data.archive_file.authorizer_zip.output_path
  source_code_hash = data.archive_file.authorizer_zip.output_base64sha256

  environment {
    variables = {
      AUTH_TABLE_NAME = aws_dynamodb_table.auth.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.authorizer,
    aws_iam_role_policy.authorizer
  ]
}

resource "aws_lambda_function" "read" {
  function_name = local.read_fn_name
  role          = aws_iam_role.read.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10

  filename         = data.archive_file.read_zip.output_path
  source_code_hash = data.archive_file.read_zip.output_base64sha256

  environment {
    variables = {
      DATA_TABLE_NAME = aws_dynamodb_table.data.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.read,
    aws_iam_role_policy.read
  ]
}

resource "aws_lambda_function" "write" {
  function_name = local.write_fn_name
  role          = aws_iam_role.write.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10

  filename         = data.archive_file.write_zip.output_path
  source_code_hash = data.archive_file.write_zip.output_base64sha256

  environment {
    variables = {
      DATA_TABLE_NAME = aws_dynamodb_table.data.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.write,
    aws_iam_role_policy.write
  ]
}
