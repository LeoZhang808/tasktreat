###############################################################################
# Route 53 module
#
# Creates a public hosted zone for a domain that is REGISTERED at Name.com.
# Terraform cannot change the registrar's nameservers, so after the first
# apply you must copy the four `name_servers` outputs into Name.com's
# "Manage Nameservers" page and replace Name.com's defaults. Until that is
# done DNS for the domain still answers from Name.com and ACM DNS-validation
# records created in this zone are invisible to the rest of the internet.
#
# This module owns the zone only. Per-record resources (ACM validation,
# Ingress alias) live in the modules that need them so each Terraform
# module stays single-purpose.
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

resource "aws_route53_zone" "this" {
  name          = var.domain_name
  comment       = "Public hosted zone for ${var.domain_name} (managed by Terraform, registrar: Name.com)"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name      = var.domain_name
    Component = "dns"
  })
}
