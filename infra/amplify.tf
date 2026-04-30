resource "aws_amplify_app" "read-for-me-frontend" {
  name                 = "read-for-me-frontend"
  iam_service_role_arn = aws_iam_role.amplify-role.arn

  custom_rule {
    source = "/"
    status = "200"
    target = "/index.html"
  }
}

resource "aws_amplify_branch" "dev" {
  app_id      = aws_amplify_app.read-for-me-frontend.id
  branch_name = "dev"
  stage       = "DEVELOPMENT"
}

resource "aws_iam_role" "amplify-role" {
  name              = "amplify-role"
 assume_role_policy = data.aws_iam_policy_document.assume_role_amplify.json
}

resource "aws_iam_policy" "amplify-policy" {
  name = "amplify-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action  = ["s3:GetObject", "s3:ListBucket"]
            Effect   = "Allow"
            Resource = ["arn:aws:s3:::${var.frontend-bucket}/*", "arn:aws:s3:::${var.frontend-bucket}"]
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach-policy-to-amplify" {
  role       = aws_iam_role.amplify-role.name
  policy_arn = aws_iam_policy.amplify-policy.arn
}

output "amplify_app_id" {
  value = aws_amplify_app.read-for-me-frontend.id
}

output "amplify_app_url" {
  value = "https://dev.${aws_amplify_app.read-for-me-frontend.default_domain}"
}