resource "aws_apigatewayv2_api" "taxi" {
  name          = "${var.product}-${var.service}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "taxi_api" {
  api_id = aws_apigatewayv2_api.taxi.id

  name        = "production"
  auto_deploy = true

  //  access_log_settings {
  //    destination_arn = aws_cloudwatch_log_group.api_cartographie_nationale.arn
  //
  //    format = jsonencode({
  //      requestId               = "$context.requestId"
  //      sourceIp                = "$context.identity.sourceIp"
  //      requestTime             = "$context.requestTime"
  //      protocol                = "$context.protocol"
  //      httpMethod              = "$context.httpMethod"
  //      resourcePath            = "$context.resourcePath"
  //      routeKey                = "$context.routeKey"
  //      status                  = "$context.status"
  //      responseLength          = "$context.responseLength"
  //      integrationErrorMessage = "$context.integrationErrorMessage"
  //    })
  //  }
}

resource "aws_apigatewayv2_route" "my_route" {
  api_id    = aws_apigatewayv2_api.taxi.id
  route_key = "$default"

  target = "integrations/${aws_apigatewayv2_integration.my_integration.id}"
}

resource "aws_apigatewayv2_integration" "my_integration" {
  api_id           = aws_apigatewayv2_api.taxi.id
  integration_type = "HTTP_PROXY"

  integration_method = "ANY"
  connection_type    = "INTERNET"
  integration_uri    = "http://api-load-balancer-2041841513.us-east-1.elb.amazonaws.com"
}

resource "aws_apigatewayv2_deployment" "my_deployment" {
  api_id = aws_apigatewayv2_api.taxi.id

  depends_on = [aws_apigatewayv2_route.my_route]
}