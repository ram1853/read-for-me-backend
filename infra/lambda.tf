variable "function_name" {
  type    = string
  default = "upload-url-generator"
}

variable "s3-bucket-name" {
  type = string
  default = "read-for-me"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "assume_role" {
    statement {
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }

      actions = ["sts:AssumeRole"]
    }
}

resource "aws_iam_policy" "cloudwatch-policy" {
  name = "url-generator-cloudwatch-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["logs:CreateLogStream", "logs:PutLogEvents"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name}:*"
        },
        {
            Action  = ["logs:CreateLogGroup"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
    ]
  })
}

resource "aws_iam_policy" "s3-policy" {
  name = "url-generator-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["s3:PutObject"]
            Effect   = "Allow"
            Resource = ["arn:aws:s3:::${var.s3-bucket-name}/*"]
        }
    ]
  })
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.url-generator-api.id}/*/${aws_api_gateway_method.post-method.http_method}${aws_api_gateway_resource.upload-url.path}"
}

# IAM Role that will be assumed by Lambda
resource "aws_iam_role" "url-generator-role" {
  name               = "url-generator-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach-cloudwatch-policy" {
  role       = aws_iam_role.url-generator-role.name
  policy_arn = aws_iam_policy.cloudwatch-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-s3-policy" {
  role       = aws_iam_role.url-generator-role.name
  policy_arn = aws_iam_policy.s3-policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../functions/upload_url_generator.py" 
  output_path = "${path.module}/lambda_function.zip" 
}


resource "aws_lambda_function" "upload-url-generator" {
  function_name     = var.function_name
  role              = aws_iam_role.url-generator-role.arn
  runtime           = "python3.14"
  handler           = "upload_url_generator.lambda_handler"
  timeout           = 60
  filename          = data.archive_file.lambda_zip.output_path
  source_code_hash  = data.archive_file.lambda_zip.output_base64sha256
}