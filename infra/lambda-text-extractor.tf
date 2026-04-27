resource "aws_iam_policy" "text-extractor-cloudwatch-policy" {
  name = "text-extractor-cloudwatch-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["logs:CreateLogStream", "logs:PutLogEvents"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name_text_extractor}:*"
        },
        {
            Action  = ["logs:CreateLogGroup"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
    ]
  })
}

resource "aws_iam_policy" "text-extractor-s3-policy" {
  name = "text-extractor-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["s3:GetObject", "s3:HeadObject"]
            Effect   = "Allow"
            Resource = ["arn:aws:s3:::${var.s3-bucket-name}/*"]
        }
    ]
  })
}

resource "aws_iam_policy" "text-extractor-textract-policy" {
  name = "text-extractor-textract-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["textract:DetectDocumentText"]
            Effect   = "Allow"
            Resource = ["*"]
        }
    ]
  })
}

resource "aws_iam_policy" "text-extractor-dynamodb-policy" {
  name = "text-extractor-dynamodb-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["dynamodb:PutItem"]
            Effect   = "Allow"
            Resource = [aws_dynamodb_table.read-for-me.arn]
        }
    ]
  })
}

# IAM Role that will be assumed by Lambda
resource "aws_iam_role" "text-extractor-role" {
  name               = "text-extractor-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_role_policy_attachment" "attach-cloudwatch-policy-to-text-extractor" {
  role       = aws_iam_role.text-extractor-role.name
  policy_arn = aws_iam_policy.text-extractor-cloudwatch-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-s3-policy-to-text-extractor" {
  role       = aws_iam_role.text-extractor-role.name
  policy_arn = aws_iam_policy.text-extractor-s3-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-textract-policy-to-text-extractor" {
  role       = aws_iam_role.text-extractor-role.name
  policy_arn = aws_iam_policy.text-extractor-textract-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-dynamodb-policy-to-text-extractor" {
  role       = aws_iam_role.text-extractor-role.name
  policy_arn = aws_iam_policy.text-extractor-dynamodb-policy.arn
}

data "archive_file" "lambda_zip_text_extractor" {
  type        = "zip"
  source_file = "${path.module}/../backend/text_extractor.py" 
  output_path = "${path.module}/../backend/lambda_function_text_extractor.zip" 
}


resource "aws_lambda_function" "text-extractor" {
  function_name     = var.function_name_text_extractor
  role              = aws_iam_role.text-extractor-role.arn
  runtime           = "python3.14"
  handler           = "text_extractor.lambda_handler"
  timeout           = 60
  filename          = data.archive_file.lambda_zip_text_extractor.output_path
  source_code_hash  = data.archive_file.lambda_zip_text_extractor.output_base64sha256
}

resource "aws_lambda_permission" "state_machine_lambda_permission_for_text_extractor" {
  statement_id  = "AllowExecutionFromStateMachine"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name_text_extractor
  principal     = "states.amazonaws.com"
  source_arn = aws_sfn_state_machine.read-for-me-job-processing-state-machine.arn
}