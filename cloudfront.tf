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

resource "aws_cloudfront_distribution" "taxi_aymeric" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  aliases = [local.domainName]

  //  custom_error_response {
  //    error_caching_min_ttl = 7200
  //    error_code            = 404
  //    response_code         = 200
  //    response_page_path    = "/index.html"
  //  }

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
  }

  ordered_cache_behavior {
    # Using the CachingDisabled managed policy ID: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-caching-disabled
    # Using the CORS-CustomOrigin managed origin request policies ID: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
    path_pattern             = "/api/*"
    allowed_methods          = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods           = ["HEAD", "GET"]
    target_origin_id         = local.api_origin_id
    compress                 = true
    viewer_protocol_policy   = "https-only"
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "59781a5b-3903-41f3-afcb-af62929ccde1"
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
