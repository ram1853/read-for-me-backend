resource "aws_iam_policy" "download-url-generator-cloudwatch-policy" {
  name = "download-url-generator-cloudwatch-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["logs:CreateLogStream", "logs:PutLogEvents"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name_download_url_generator}:*"
        },
        {
            Action  = ["logs:CreateLogGroup"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
    ]
  })
}

resource "aws_iam_policy" "download-url-generator-s3-policy" {
  name = "download-url-generator-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["s3:GetObject"]
            Effect   = "Allow"
            Resource = ["arn:aws:s3:::${var.s3-bucket-name}/*"]
        }
    ]
  })
}

resource "aws_iam_policy" "download-url-generator-dynamodb-policy" {
  name = "download-url-generator-dynamodb-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["dynamodb:GetItem"]
            Effect   = "Allow"
            Resource = [aws_dynamodb_table.read-for-me.arn]
        }
    ]
  })
}

resource "aws_lambda_permission" "apigw_lambda_download_url_generator" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name_download_url_generator
  principal     = "apigateway.amazonaws.com"
  source_arn = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.url-generator-api.id}/*/${aws_api_gateway_method.download-post-method.http_method}${aws_api_gateway_resource.download-url.path}"
}

# IAM Role that will be assumed by Lambda
resource "aws_iam_role" "download-url-generator-role" {
  name               = "download-url-generator-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_role_policy_attachment" "attach-cloudwatch-policy-to-download-url-generator" {
  role       = aws_iam_role.download-url-generator-role.name
  policy_arn = aws_iam_policy.download-url-generator-cloudwatch-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-s3-policy-to-download-url-generator" {
  role       = aws_iam_role.download-url-generator-role.name
  policy_arn = aws_iam_policy.download-url-generator-s3-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-dynamodb-policy-to-download-url-generator" {
  role       = aws_iam_role.download-url-generator-role.name
  policy_arn = aws_iam_policy.download-url-generator-dynamodb-policy.arn
}

data "archive_file" "lambda_zip_download_url_generator" {
  type        = "zip"
  source_file = "${path.module}/../backend/download_url_generator.py" 
  output_path = "${path.module}/../backend/lambda_function_download_url_generator.zip" 
}


resource "aws_lambda_function" "download-url-generator" {
  function_name     = var.function_name_download_url_generator
  role              = aws_iam_role.download-url-generator-role.arn
  runtime           = "python3.14"
  handler           = "download_url_generator.lambda_handler"
  timeout           = 60
  filename          = data.archive_file.lambda_zip_download_url_generator.output_path
  source_code_hash  = data.archive_file.lambda_zip_download_url_generator.output_base64sha256
}