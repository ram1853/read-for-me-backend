resource "aws_amplify_app" "read-for-me-frontend" {
  name = "read-for-me-frontend"

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