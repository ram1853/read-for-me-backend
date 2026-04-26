resource "aws_iam_policy" "language-detector-cloudwatch-policy" {
  name = "language-detector-cloudwatch-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["logs:CreateLogStream", "logs:PutLogEvents"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name_language_detector}:*"
        },
        {
            Action  = ["logs:CreateLogGroup"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
    ]
  })
}

resource "aws_iam_policy" "language-detector-comprehend-policy" {
  name = "language-detector-comprehend-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["comprehend:DetectDominantLanguage"]
            Effect   = "Allow"
            Resource = ["*"]
        }
    ]
  })
}

resource "aws_iam_policy" "language-detector-dynamodb-policy" {
  name = "language-detector-dynamodb-policy"
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
resource "aws_iam_role" "language-detector-role" {
  name               = "language-detector-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_role_policy_attachment" "attach-cloudwatch-policy-to-language-detector" {
  role       = aws_iam_role.language-detector-role.name
  policy_arn = aws_iam_policy.language-detector-cloudwatch-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-comprehend-policy-to-language-detector" {
  role       = aws_iam_role.language-detector-role.name
  policy_arn = aws_iam_policy.language-detector-comprehend-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-dynamodb-policy-to-language-detector" {
  role       = aws_iam_role.language-detector-role.name
  policy_arn = aws_iam_policy.language-detector-dynamodb-policy.arn
}

data "archive_file" "lambda_zip_language_detector" {
  type        = "zip"
  source_file = "${path.module}/../functions/language_detector.py" 
  output_path = "${path.module}/lambda_function_language_detector.zip" 
}


resource "aws_lambda_function" "language-detector" {
  function_name     = var.function_name_language_detector
  role              = aws_iam_role.language-detector-role.arn
  runtime           = "python3.14"
  handler           = "language_detector.lambda_handler"
  timeout           = 60
  filename          = data.archive_file.lambda_zip_language_detector.output_path
  source_code_hash  = data.archive_file.lambda_zip_language_detector.output_base64sha256
}

resource "aws_lambda_permission" "state_machine_lambda_permission_for_language_detector" {
  statement_id  = "AllowExecutionFromStateMachine"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name_language_detector
  principal     = "states.amazonaws.com"
  source_arn = aws_sfn_state_machine.read-for-me-job-processing-state-machine.arn
}