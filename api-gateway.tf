resource "aws_apigatewayv2_api" "taxi" {
  name          = "${var.product}-${var.service}"
  protocol_type = "HTTP"

  disable_execute_api_endpoint = false
}

resource "aws_apigatewayv2_stage" "taxi_api" {
  api_id = aws_apigatewayv2_api.taxi.id

  name        = "$default"
  auto_deploy = true
}

data "aws_cognito_user_pools" "taxi-aymeric-user-pool" {
  name = "taxi-aymeric-user-pool"
}

data "aws_cognito_user_pool_clients" "taxi-aymeric-user-pool-client" {
  user_pool_id = tolist(data.aws_cognito_user_pools.taxi-aymeric-user-pool.ids)[0]
}

resource "aws_apigatewayv2_authorizer" "cognito_authorizer" {
  api_id           = aws_apigatewayv2_api.taxi.id
  name             = "cognito-authorizer"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${tolist(data.aws_cognito_user_pools.taxi-aymeric-user-pool.ids)[0]}"
    audience = ["${data.aws_cognito_user_pool_clients.taxi-aymeric-user-pool-client.client_ids[0]}"]
  }
}

resource "aws_apigatewayv2_route" "my_route" {
  api_id    = aws_apigatewayv2_api.taxi.id
  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.test_interface_integration.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_authorizer.id

}

resource "aws_apigatewayv2_integration" "test_interface_integration" {
  api_id             = aws_apigatewayv2_api.taxi.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.vpc_link.id
  integration_uri    = aws_lb_listener.api_listener_http.arn

}

//resource "aws_apigatewayv2_integration" "my_integration" {
//  api_id             = aws_apigatewayv2_api.taxi.id
//  integration_type   = "HTTP_PROXY"
//  integration_method = "ANY"
//  connection_type    = "VPC_LINK"
//  connection_id      = aws_apigatewayv2_vpc_link.vpc_link.id
//  integration_uri    = aws_lb_listener.api_listener_http.arn
//
//}
//
//resource "aws_apigatewayv2_deployment" "my_deployment" {
//  api_id = aws_apigatewayv2_api.taxi.id
//
//  depends_on = [aws_apigatewayv2_route.my_route]
//}

resource "aws_apigatewayv2_vpc_link" "vpc_link" {
  name               = "vpc-link-to-internal-load-balancer"
  subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids = []

  tags = local.tags
}