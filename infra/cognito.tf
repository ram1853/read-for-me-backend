resource "aws_cognito_user_pool" "read-for-me-users" {
  name = "read-for-me-user-pool"
  auto_verified_attributes = ["email"]

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = true  
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 2048
    }
  }
}

resource "aws_cognito_user_pool_client" "userpool-client" {
  name                                 = "userpool-client"
  user_pool_id                         = aws_cognito_user_pool.read-for-me-users.id
  callback_urls                        = ["https://dev.d1trqyve4ac16v.amplifyapp.com"]
  logout_urls                          = ["https://dev.d1trqyve4ac16v.amplifyapp.com"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "phone"]
  supported_identity_providers         = ["COGNITO"]
  explicit_auth_flows                  = ["ALLOW_USER_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
}

resource "aws_cognito_managed_login_branding" "managed-login" {
  client_id    = aws_cognito_user_pool_client.userpool-client.id
  user_pool_id = aws_cognito_user_pool.read-for-me-users.id

  use_cognito_provided_values = true
}

resource "aws_cognito_user_pool_domain" "userpool-domain" {
  domain       = "userpool-domain"
  user_pool_id = aws_cognito_user_pool.read-for-me-users.id
}


