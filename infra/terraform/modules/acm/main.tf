###############################################################################
# ACM module
#
# Issues a DNS-validated ACM certificate for `var.domain_name` (and any
# `subject_alternative_names`) and creates the validation CNAME records
# in the Route 53 hosted zone passed in. The certificate is created in
# whichever AWS region the calling provider is configured for, which MUST
# be the same region as the ALB (us-west-2 for this project).
#
# A separate `aws_acm_certificate_validation` resource blocks Terraform
# until ACM observes the validation records and flips the certificate to
# ISSUED, so downstream resources (e.g. the Ingress that wires the cert
# ARN into the ALB listener) only see a certificate that is actually
# usable.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = merge(var.tags, {
    Name      = var.domain_name
    Component = "tls"
  })

  # Replace before destroy so the cert can be rotated without an outage:
  # the new cert is issued and attached to the ALB before the old one is
  # removed.
  lifecycle {
    create_before_destroy = true
  }
}

# ACM emits one validation record per (cert, FQDN) pair. We dedupe on the
# record name so SANs that share a validation record don't collide in the
# for_each map.
locals {
  validation_records = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.validation_records

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  # ACM validation records are owned by Terraform; if a stale one exists in
  # the zone (e.g. from a previous failed apply) we want to take it over
  # rather than fail.
  allow_overwrite = true
}

# Blocks until ACM has actually validated the cert. Anything that consumes
# `module.acm.certificate_arn` (e.g. the Ingress) should depend on this
# resource transitively so it never sees a Pending Validation cert.
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]

  timeouts {
    create = var.validation_timeout
  }
}
