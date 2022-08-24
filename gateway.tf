
# aws_api_gateway_rest_api.route
resource "aws_api_gateway_rest_api" "route" {
  name        = "${var.site}_route"
  description = "Lambda-powered route API"
  disable_execute_api_endpoint = true

  depends_on = [
    aws_lambda_function.dyndns_lamda
  ]
}

# aws_api_gateway_method.dyndns_lamda_root
resource "aws_api_gateway_method" "dyndns_lamda_root" {
  rest_api_id   = aws_api_gateway_rest_api.route.id
  resource_id   = aws_api_gateway_rest_api.route.root_resource_id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.mode" = true,
    "method.request.querystring.hostname" = true,
    "method.request.querystring.hash" = false,
    "method.request.querystring.internalIp" = false
  }
}

# aws_api_gateway_integration.dyndns_lamda_root
resource "aws_api_gateway_integration" "dyndns_lamda_root" {
  rest_api_id = aws_api_gateway_rest_api.route.id
  resource_id = aws_api_gateway_method.dyndns_lamda_root.resource_id
  http_method = aws_api_gateway_method.dyndns_lamda_root.http_method

  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.dyndns_lamda.invoke_arn

  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
      "application/json" = <<EOF
{
    "execution_mode" : "$input.params('mode')",
    "source_ip" : "$context.identity.sourceIp",
    "internal_ip" : "$input.params('internalIp')",
    "query_string" : "$input.params().querystring",
    "set_hostname" : "$input.params('hostname')",
    "validation_hash" : "$input.params('hash')"
}
  EOF
  }
}

# -----------------------------------------------------------------------------------------------------------
# Deployment

# aws_api_gateway_stage.prod
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.dyndns_lamda.id
  rest_api_id   = aws_api_gateway_rest_api.route.id
  stage_name    = "prod"

  depends_on = [
    aws_api_gateway_deployment.dyndns_lamda
  ]
}

resource "aws_api_gateway_deployment" "dyndns_lamda" {
  rest_api_id = aws_api_gateway_rest_api.route.id

  depends_on = [
    aws_api_gateway_integration.dyndns_lamda_root,
    aws_api_gateway_method.dyndns_lamda_root,

    aws_api_gateway_rest_api_policy.route_public_access,
  ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.route,
      aws_lambda_function.dyndns_lamda,
      aws_api_gateway_method.dyndns_lamda_root,
      aws_api_gateway_integration.dyndns_lamda_root,

      aws_api_gateway_method_response.response_200,
      aws_api_gateway_integration_response.response_200,

      aws_api_gateway_rest_api_policy.route_public_access, # REDEPLOY MUST HAPPEN IF PERMISSIONS CHANGE
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dyndns_lamda.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.route.execution_arn}/*/*"
}

output "base_url" {
  value = aws_api_gateway_deployment.dyndns_lamda.invoke_url
}

output "lambda_public_url" {
  value = "${aws_api_gateway_deployment.dyndns_lamda.invoke_url}"
}

data "aws_iam_policy_document" "public_api_access" {
  statement {
    actions = ["execute-api:Invoke"]

    principals {
      type = "AWS"
      identifiers = [ "*" ]
    }

    resources = [ "${aws_api_gateway_rest_api.route.execution_arn}/*/*" ]
  }
}

resource "aws_api_gateway_rest_api_policy" "route_public_access" {
  rest_api_id = aws_api_gateway_rest_api.route.id
  policy = data.aws_iam_policy_document.public_api_access.json
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.route.id
  resource_id = aws_api_gateway_method.dyndns_lamda_root.resource_id
  http_method = aws_api_gateway_method.dyndns_lamda_root.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "response_500" {
  rest_api_id = aws_api_gateway_rest_api.route.id
  resource_id = aws_api_gateway_method.dyndns_lamda_root.resource_id
  http_method = aws_api_gateway_method.dyndns_lamda_root.http_method
  status_code = "500"
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.route.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "ERROR"
  }
}

resource "aws_api_gateway_integration_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.route.id
  resource_id = aws_api_gateway_method.dyndns_lamda_root.resource_id
  http_method = aws_api_gateway_method.dyndns_lamda_root.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
}

resource "aws_api_gateway_gateway_response" "gateway-response" {
  rest_api_id   = aws_api_gateway_rest_api.route.id
  status_code   = "403"
  response_type = "INVALID_API_KEY"
  response_templates = {
    "application/json" = "{\"status\":403,\"layer\":\"Gateway\",\"request-id\":\"$context.requestId\",\"code\":\"$context.error.responseType\",\"message\":\"$context.error.message\"}"
  }
}

resource "aws_api_gateway_domain_name" "api" {
  domain_name     = "${var.api_subdomain}.${var.domain}"
  certificate_arn = aws_acm_certificate.cert.arn

  depends_on = [
    aws_acm_certificate.cert
  ]
}

resource "aws_api_gateway_base_path_mapping" "api" {
  api_id      = aws_api_gateway_rest_api.route.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.api.domain_name
}

resource "aws_route53_record" "api" {
  name    = aws_api_gateway_domain_name.api.domain_name
  type    = "A"
  zone_id = aws_route53_zone.zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.api.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api.cloudfront_zone_id
  }
}