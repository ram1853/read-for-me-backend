resource "aws_sfn_state_machine" "read-for-me-job-processing-state-machine" {
  depends_on = [ aws_lambda_function.text-extractor ]
  name     = "read-for-me-job-processing-state-machine"
  role_arn = aws_iam_role.step_function_execution_role.arn

  definition = <<EOF
{
  "Comment": "State Machine for read-for-me job",
  "StartAt": "text-extractor",
  "States": {
    "text-extractor": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.text-extractor.arn}",
      "End": true
    }
  }
}
EOF
}

resource "aws_iam_role" "step_function_execution_role" {
  name = "step_function_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_state_machine.json
}

resource "aws_iam_policy" "state-machine-lambda-invoke-policy" {
  name   = "state-machine-lambda-invoke-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"] 
      Resource = [aws_lambda_function.text-extractor.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_policy" {
  role       = aws_iam_role.step_function_execution_role.name
  policy_arn = aws_iam_policy.state-machine-lambda-invoke-policy.arn
}
