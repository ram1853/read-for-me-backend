resource "aws_iam_policy" "audio-generator-cloudwatch-policy" {
  name = "audio-generator-cloudwatch-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["logs:CreateLogStream", "logs:PutLogEvents"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name_audio_generator}:*"
        },
        {
            Action  = ["logs:CreateLogGroup"]
            Effect   = "Allow"
            Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
    ]
  })
}

resource "aws_iam_policy" "audio-generator-polly-policy" {
  name = "audio-generator-polly-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["polly:SynthesizeSpeech"]
            Effect   = "Allow"
            Resource = ["*"]
        }
    ]
  })
}

resource "aws_iam_policy" "audio-generator-dynamodb-policy" {
  name = "audio-generator-dynamodb-policy"
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

resource "aws_iam_policy" "audio-generator-s3-policy" {
  name = "audio-generator-s3-policy"
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

# IAM Role that will be assumed by Lambda
resource "aws_iam_role" "audio-generator-role" {
  name               = "audio-generator-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_role_policy_attachment" "attach-cloudwatch-policy-to-audio-generator" {
  role       = aws_iam_role.audio-generator-role.name
  policy_arn = aws_iam_policy.audio-generator-cloudwatch-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-polly-policy-to-audio-generator" {
  role       = aws_iam_role.audio-generator-role.name
  policy_arn = aws_iam_policy.audio-generator-polly-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-dynamodb-policy-to-audio-generator" {
  role       = aws_iam_role.audio-generator-role.name
  policy_arn = aws_iam_policy.audio-generator-dynamodb-policy.arn
}

resource "aws_iam_role_policy_attachment" "attach-s3-policy-to-audio-generator" {
  role       = aws_iam_role.audio-generator-role.name
  policy_arn = aws_iam_policy.audio-generator-s3-policy.arn
}

data "archive_file" "lambda_zip_audio_generator" {
  type        = "zip"
  source_file = "${path.module}/../backend/audio_generator.py" 
  output_path = "${path.module}/../backend/lambda_function_audio_generator.zip" 
}


resource "aws_lambda_function" "audio-generator" {
  function_name     = var.function_name_audio_generator
  role              = aws_iam_role.audio-generator-role.arn
  runtime           = "python3.14"
  handler           = "audio_generator.lambda_handler"
  timeout           = 60
  filename          = data.archive_file.lambda_zip_audio_generator.output_path
  source_code_hash  = data.archive_file.lambda_zip_audio_generator.output_base64sha256
}

resource "aws_lambda_permission" "state_machine_lambda_permission_for_audio_generator" {
  statement_id  = "AllowExecutionFromStateMachine"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name_audio_generator
  principal     = "states.amazonaws.com"
  source_arn = aws_sfn_state_machine.read-for-me-job-processing-state-machine.arn
}