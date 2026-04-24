# Event Bridge Notification has to be turned on from the s3 side.

resource "aws_cloudwatch_event_rule" "file_upload_event" {
  name        = "file-upload-event"
  description = "Capture file upload event in s3"
  
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = ["read-for-me"]
      }
      object = {
        key = [{
          "anything-but" = {
            wildcard = ["*mp3*"]
          }
        }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_state_machine" {
  rule     = aws_cloudwatch_event_rule.file_upload_event.name
  arn      = aws_sfn_state_machine.read-for-me-job-processing-state-machine.arn
  role_arn = aws_iam_role.eventbridge_target_role.arn
}

# IAM Role for EventBridge to invoke Step Functions
resource "aws_iam_role" "eventbridge_target_role" {
  name               = "eventbridge-target-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_events.json
}

resource "aws_iam_policy" "target_access" {
  name = "eventbridge-target-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = [aws_sfn_state_machine.read-for-me-job-processing-state-machine.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_step_function_policy" {
  role       = aws_iam_role.eventbridge_target_role.name
  policy_arn = aws_iam_policy.target_access.arn
}