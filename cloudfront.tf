data "aws_s3_bucket" "client" {
  bucket = replace("${local.product_information.context.product}_${local.service.taxi_aymeric.client.name}", "_", "-")
}

resource "aws_cloudfront_origin_access_identity" "client" {
  comment = "S3 cloudfront origin access identity for ${local.service.taxi_aymeric.client.title} service in ${local.productTitle}"
}

locals {
  s3_origin_id  = "${local.service.taxi_aymeric.client.name}_s3"
  api_origin_id = "${var.product}_api"
}

//resource "aws_cloudfront_cache_policy" "api_cache_policy" {
//  name        = "example-policy"
//  comment     = "test comment"
//  default_ttl = 0
//  max_ttl     = 0
//  min_ttl     = 0
//
//  parameters_in_cache_key_and_forwarded_to_origin {
//    cookies_config {
//      cookie_behavior = "none"
//    }
//    headers_config {
//      header_behavior = "whitelist"
//      headers {
//        items = ["Authorization"]
//      }
//    }
//    query_strings_config {
//      query_string_behavior = "all"
//    }
//  }
//}

resource "aws_cloudfront_response_headers_policy" "security_headers_policy" {
  name = "taxi-gestion-security-headers-policy"

  custom_headers_config {
    items {
      header   = "permissions-policy"
      override = true
      value    = "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
    }
  }

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "same-origin"
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
    strict_transport_security {
      access_control_max_age_sec = "63072000"
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self' data: https://cognito-idp.us-east-1.amazonaws.com ; font-src 'self'; img-src 'self'; object-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; trusted-types angular angular#bundler dompurify; require-trusted-types-for 'script';"
      override                = true
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "response_headers_policy_api" {
  name = "taxi-gestion-response-headers-policy-api"

  custom_headers_config {
    items {
      header   = "permissions-policy"
      override = true
      value    = "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
    }
  }

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
    strict_transport_security {
      access_control_max_age_sec = "63072000"
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self';"
      override                = false
    }
  }
}

resource "aws_cloudfront_distribution" "taxi_aymeric" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  aliases = [local.domainName]

  custom_error_response {
    error_caching_min_ttl = 7200
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  origin {
    domain_name = data.aws_s3_bucket.client.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.client.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = replace(aws_apigatewayv2_api.taxi.api_endpoint, "/^https?://([^/]*).*/", "$1")
    origin_id   = local.api_origin_id
    origin_path = "/production"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    default_ttl            = 3600
    min_ttl                = 0
    max_ttl                = 86400
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers_policy.id

  }

  ordered_cache_behavior {
    # Using the CachingDisabled managed policy ID: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-caching-disabled
    # Using the AllViewerExceptHostHeader managed origin request policies ID: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
    path_pattern               = "/api/*"
    allowed_methods            = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods             = ["HEAD", "GET"]
    target_origin_id           = local.api_origin_id
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" //aws_cloudfront_cache_policy.api_cache_policy.id
    origin_request_policy_id   = "b689b0a8-53d0-40ab-baf2-68738e2966ac" //"59781a5b-3903-41f3-afcb-af62929ccde1"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.response_headers_policy_api.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.remove_api_from_uri.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["FR"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.acm_certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = local.tags
}

data "aws_iam_policy_document" "client_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.client.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.client.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.client.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.client.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "client" {
  bucket = data.aws_s3_bucket.client.id
  policy = data.aws_iam_policy_document.client_s3_policy.json
}

resource "aws_cloudfront_function" "remove_api_from_uri" {
  name    = "rewrite-request-remove-api-from-uri"
  runtime = "cloudfront-js-1.0"
  code    = <<EOF
function handler(event) {
	var request = event.request;
	request.uri = request.uri.replace(/\/api\//, "/");
	return request;
}
EOF
}
