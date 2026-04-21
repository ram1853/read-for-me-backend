resource "aws_api_gateway_rest_api" "url-generator-api" {
  name = "url-generator-api"
  endpoint_configuration {
    types = [ "REGIONAL" ]
  }
}

resource "aws_api_gateway_resource" "upload-url" {
  path_part   = "upload-url"
  parent_id   = aws_api_gateway_rest_api.url-generator-api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.url-generator-api.id
}

resource "aws_api_gateway_method" "post-method" {
  rest_api_id   = aws_api_gateway_rest_api.url-generator-api.id
  resource_id   = aws_api_gateway_resource.upload-url.id
  http_method   = "POST"
  authorization = "NONE"
}

# For CORS
resource "aws_api_gateway_method" "options-method" {
  rest_api_id   = aws_api_gateway_rest_api.url-generator-api.id
  resource_id   = aws_api_gateway_resource.upload-url.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api-lambda-mock-integration" {
  rest_api_id             = aws_api_gateway_rest_api.url-generator-api.id
  resource_id             = aws_api_gateway_resource.upload-url.id
  http_method             = aws_api_gateway_method.options-method.http_method
  type                    = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

# Integration response for OPTIONS
resource "aws_api_gateway_integration_response" "options_upload_url_integration_response" {
  depends_on = [ aws_api_gateway_integration.api-lambda-mock-integration, aws_api_gateway_method_response.options_upload_url_method_response ]
  rest_api_id = aws_api_gateway_rest_api.url-generator-api.id
  resource_id = aws_api_gateway_resource.upload-url.id
  http_method = aws_api_gateway_method.options-method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Method response for OPTIONS
resource "aws_api_gateway_method_response" "options_upload_url_method_response" {
  rest_api_id = aws_api_gateway_rest_api.url-generator-api.id
  resource_id = aws_api_gateway_resource.upload-url.id
  http_method = aws_api_gateway_method.options-method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "api-lambda-integration" {
  rest_api_id             = aws_api_gateway_rest_api.url-generator-api.id
  resource_id             = aws_api_gateway_resource.upload-url.id
  http_method             = aws_api_gateway_method.post-method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload-url-generator.invoke_arn
}

resource "aws_api_gateway_deployment" "dev-deployment" {
  depends_on  = [aws_api_gateway_integration.api-lambda-integration, aws_api_gateway_integration.api-lambda-mock-integration]
  rest_api_id = aws_api_gateway_rest_api.url-generator-api.id
  # Any change done to the API should be re-deployed to take effect.
  # The below trigger does not seem to work during any changes (meaning re-deployment did not happen automatically)
  triggers = {
    api_body_hash = sha256(jsonencode(aws_api_gateway_rest_api.url-generator-api.body))
    }
}

resource "aws_api_gateway_stage" "dev" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.url-generator-api.id
  deployment_id = aws_api_gateway_deployment.dev-deployment.id
}