resource "aws_route53_delegation_set" "domain_delegation_set" {
  reference_name = "Taxi-gestion name server delegation set"
}

resource "aws_route53domains_registered_domain" "registered_domain" {
  domain_name = local.domainName

  dynamic "name_server" {
    for_each = aws_route53_delegation_set.domain_delegation_set.name_servers
    content {
      name = name_server.value
    }
  }

  auto_renew = true

  tags = local.tags
}

resource "aws_route53_zone" "hosting_zone" {
  name              = local.domainName
  delegation_set_id = aws_route53_delegation_set.domain_delegation_set.id
  tags              = local.tags
}

resource "aws_route53_record" "main_name_servers_record" {
  name            = aws_route53_zone.hosting_zone.name
  allow_overwrite = true
  ttl             = 30
  type            = "NS"
  zone_id         = aws_route53_zone.hosting_zone.zone_id
  records         = aws_route53_zone.hosting_zone.name_servers
}

locals {
  subject_alternative_names = {
    for policy_file in fileset("${path.root}/assets/policies", "*") : trimsuffix(policy_file, ".json") => {
      name  = split("_", policy_file)[0]
      label = trimsuffix(split("_", policy_file)[1], ".json")
    }
  }
}

resource "aws_acm_certificate" "acm_certificate" {
  provider          = aws.us-east-1
  domain_name       = local.domainName
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

resource "aws_route53_record" "certificate_validation_main" {
  name            = tolist(aws_acm_certificate.acm_certificate.domain_validation_options)[0].resource_record_name
  depends_on      = [aws_acm_certificate.acm_certificate]
  zone_id         = aws_route53_zone.hosting_zone.zone_id
  type            = tolist(aws_acm_certificate.acm_certificate.domain_validation_options)[0].resource_record_type
  ttl             = "300"
  records         = [sort(aws_acm_certificate.acm_certificate.domain_validation_options[*].resource_record_value)[0]]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "certification_main" {
  provider        = aws.us-east-1
  certificate_arn = aws_acm_certificate.acm_certificate.arn
  validation_record_fqdns = [
    aws_route53_record.certificate_validation_main.fqdn,
  ]
  timeouts {
    create = "48h"
  }
}

resource "aws_route53_record" "taxi_aymeric_record_ipv4" {
  name    = aws_route53_zone.hosting_zone.name
  zone_id = aws_route53_zone.hosting_zone.zone_id
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.taxi_aymeric.domain_name
    zone_id                = aws_cloudfront_distribution.taxi_aymeric.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "driver_record_ipv6" {
  name    = aws_route53_zone.hosting_zone.name
  zone_id = aws_route53_zone.hosting_zone.zone_id
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.taxi_aymeric.domain_name
    zone_id                = aws_cloudfront_distribution.taxi_aymeric.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_record" {
  name    = "${aws_route53_zone.hosting_zone.name}/api"
  zone_id = aws_route53_zone.hosting_zone.zone_id
  type    = "A"

  alias {
    name                   = aws_lb.api_load_balancer.dns_name
    zone_id                = aws_lb.api_load_balancer.zone_id
    evaluate_target_health = false
  }
}