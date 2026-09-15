resource "aws_apigatewayv2_api" "main" {
  count         = var.auth_lambda_function_arn != null && (var.api_origin_url != null || var.api_listener_arn != null) ? 1 : 0
  name          = "${local.name}-gateway"
  protocol_type = "HTTP"
  description   = "Garage Management public entry point"
  tags          = local.common_tags
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count            = var.auth_lambda_function_arn != null && (var.api_origin_url != null || var.api_listener_arn != null) && var.jwt_issuer != null && var.jwt_audience != null ? 1 : 0
  api_id           = aws_apigatewayv2_api.main[0].id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${local.name}-jwt"
  jwt_configuration {
    audience = [var.jwt_audience]
    issuer   = var.jwt_issuer
  }
}

resource "aws_apigatewayv2_integration" "auth_lambda" {
  count                  = var.auth_lambda_function_arn != null && (var.api_origin_url != null || var.api_listener_arn != null) ? 1 : 0
  api_id                 = aws_apigatewayv2_api.main[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.auth_lambda_function_arn}/invocations"
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "api" {
  count                  = var.api_listener_arn != null && length(var.vpc_link_subnet_ids) >= 2 && length(var.vpc_link_security_group_ids) >= 1 ? 1 : 0
  api_id                 = aws_apigatewayv2_api.main[0].id
  integration_type       = "HTTP_PROXY"
  integration_uri        = var.api_listener_arn
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.api[0].id
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_vpc_link" "api" {
  count              = var.api_listener_arn != null && length(var.vpc_link_subnet_ids) >= 2 && length(var.vpc_link_security_group_ids) >= 1 ? 1 : 0
  name               = "${local.name}-api-vpc-link"
  subnet_ids         = var.vpc_link_subnet_ids
  security_group_ids = var.vpc_link_security_group_ids
  tags               = local.common_tags
}

resource "aws_apigatewayv2_route" "auth" {
  count     = var.auth_lambda_function_arn != null && (var.api_origin_url != null || var.api_listener_arn != null) ? 1 : 0
  api_id    = aws_apigatewayv2_api.main[0].id
  route_key = "POST /auth"
  target    = "integrations/${aws_apigatewayv2_integration.auth_lambda[0].id}"
}

resource "aws_apigatewayv2_route" "public_status" {
  count              = var.api_listener_arn != null && length(var.vpc_link_subnet_ids) >= 2 && length(var.vpc_link_security_group_ids) >= 1 ? 1 : 0
  api_id             = aws_apigatewayv2_api.main[0].id
  route_key          = "GET /api/service-order/public-status"
  target             = "integrations/${aws_apigatewayv2_integration.api[0].id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "protected" {
  count              = var.api_listener_arn != null && var.jwt_issuer != null && var.jwt_audience != null && length(var.vpc_link_subnet_ids) >= 2 && length(var.vpc_link_security_group_ids) >= 1 ? 1 : 0
  api_id             = aws_apigatewayv2_api.main[0].id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.api[0].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt[0].id
}

resource "aws_apigatewayv2_stage" "default" {
  count       = var.auth_lambda_function_arn != null && (var.api_origin_url != null || var.api_listener_arn != null) ? 1 : 0
  api_id      = aws_apigatewayv2_api.main[0].id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

resource "aws_lambda_permission" "api_gateway" {
  count         = var.auth_lambda_function_arn != null && (var.api_origin_url != null || var.api_listener_arn != null) ? 1 : 0
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.auth_lambda_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main[0].execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "jwks" {
  count     = var.auth_lambda_function_arn != null && (var.api_origin_url != null || var.api_listener_arn != null) ? 1 : 0
  api_id    = aws_apigatewayv2_api.main[0].id
  route_key = "GET /.well-known/jwks.json"
  target    = "integrations/${aws_apigatewayv2_integration.auth_lambda[0].id}"
}