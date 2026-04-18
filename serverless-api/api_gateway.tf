resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "Serverless REST API with Lambda authorizer"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "token" {
  name                             = "${var.project_name}-token-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.main.id
  authorizer_uri                   = aws_lambda_function.authorizer.invoke_arn
  type                             = "TOKEN"
  identity_source                  = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 0
}

resource "aws_lambda_permission" "authorizer_api_gateway" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_api_gateway_resource" "data" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "data"
}

# GET /data?id=...

resource "aws_api_gateway_method" "data_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.data.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.token.id

  request_parameters = {
    "method.request.querystring.id" = true
  }
}

resource "aws_api_gateway_integration" "data_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.data.id
  http_method = aws_api_gateway_method.data_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.read.invoke_arn
}

resource "aws_lambda_permission" "read_api_gateway" {
  statement_id  = "AllowAPIGatewayInvokeRead"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# POST /data

resource "aws_api_gateway_method" "data_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.data.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.token.id
}

resource "aws_api_gateway_integration" "data_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.data.id
  http_method = aws_api_gateway_method.data_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.write.invoke_arn
}

resource "aws_lambda_permission" "write_api_gateway" {
  statement_id  = "AllowAPIGatewayInvokeWrite"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.write.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.data.id,
      aws_api_gateway_method.data_get.id,
      aws_api_gateway_integration.data_get.id,
      aws_api_gateway_method.data_post.id,
      aws_api_gateway_integration.data_post.id,
      aws_api_gateway_authorizer.token.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.data_get,
    aws_api_gateway_integration.data_post,
  ]
}
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "prod"
}

