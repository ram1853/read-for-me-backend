resource "aws_iam_policy" "text-translator-cloudwatch-policy" {
  name = "text-translator-cloudwatch-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["logs:CreateLogStream", "logs:PutLogEvents"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name_text_translator}:*"
        },
        {
            Action  = ["logs:CreateLogGroup"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
    ]
  })
}

resource "aws_iam_policy" "text-translator-translate-policy" {
  name = "text-translator-translate-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["translate:TranslateText"]
            Effect   = "Allow"
            Resource = ["*"]
        }
    ]
  })
}

resource "aws_iam_policy" "text-translator-dynamodb-policy" {
  name = "text-translator-dynamodb-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["dynamodb:UpdateItem"]
            Effect   = "Allow"
            Resource = [aws_dynamodb_table.read-for-me.arn]
        }
    ]
  })
}

# IAM Role that will be assumed by Lambda
resource "aws_iam_role" "text-translator-role" {
  name               = "text-translator-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_role_policy_attachment" "attach-cloudwatch-policy-to-text-translator" {
  role       = aws_iam_role.text-translator-role.name
  policy_arn = aws_iam_policy.text-translator-cloudwatch-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-translate-policy-to-text-translator" {
  role       = aws_iam_role.text-translator-role.name
  policy_arn = aws_iam_policy.text-translator-translate-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-dynamodb-policy-to-text-translator" {
  role       = aws_iam_role.text-translator-role.name
  policy_arn = aws_iam_policy.text-translator-dynamodb-policy.arn
}

data "archive_file" "lambda_zip_text_translator" {
  type        = "zip"
  source_file = "${path.module}/../functions/text_translator.py" 
  output_path = "${path.module}/lambda_function_text_translator.zip" 
}


resource "aws_lambda_function" "text-translator" {
  function_name     = var.function_name_text_translator
  role              = aws_iam_role.text-translator-role.arn
  runtime           = "python3.14"
  handler           = "text_translator.lambda_handler"
  timeout           = 60
  filename          = data.archive_file.lambda_zip_text_translator.output_path
  source_code_hash  = data.archive_file.lambda_zip_text_translator.output_base64sha256
}

resource "aws_lambda_permission" "state_machine_lambda_permission_for_text_translator" {
  statement_id  = "AllowExecutionFromStateMachine"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name_text_translator
  principal     = "states.amazonaws.com"
  source_arn = aws_sfn_state_machine.read-for-me-job-processing-state-machine.arn
}