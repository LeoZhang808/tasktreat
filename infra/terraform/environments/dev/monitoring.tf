###############################################################################
# Monitoring stack DNS + TLS (Step 13).
#
# This file owns:
#   * ACM certificate for grafana.<apex>  (independent of the app cert)
#   * Route 53 alias record pointing grafana.<apex> at the Grafana ALB
#
# Two-step apply pattern (same chicken-and-egg as the app ALB):
#
#   1. `terraform apply` with the default `grafana_alb_provisioned = false`.
#      This creates the ACM cert; the DNS record and ALB lookup are gated
#      OFF so plan/apply succeeds even though the ALB does not exist yet.
#
#   2. Render and apply the Grafana Ingress (see
#      scripts/install-monitoring.sh) using the cert ARN output below.
#      The AWS Load Balancer Controller provisions the ALB and tags it
#      with `ingress.k8s.aws/stack=monitoring/grafana-ingress`.
#
#   3. Set `grafana_alb_provisioned = true` in terraform.tfvars and run
#      `terraform apply` again. The data source finds the ALB by tag and
#      Route 53 creates the alias.
#
# We could collapse this into a single apply by using ExternalDNS in the
# cluster, but that adds another moving piece (extra controller, IRSA role,
# RBAC). The two-step apply matches the existing app DNS pattern in this
# repo and keeps the inventory simple.
###############################################################################

# -----------------------------------------------------------------------------
# ACM cert for grafana.<apex> — separate cert (not a SAN on the app cert) so
# Grafana and the app have independent rotation lifecycles.
# -----------------------------------------------------------------------------
module "acm_grafana" {
  source = "../../modules/acm"

  domain_name    = local.grafana_fqdn
  hosted_zone_id = module.route53.zone_id

  tags = merge(local.common_tags, {
    Component = "tls-grafana"
  })
}

# -----------------------------------------------------------------------------
# Data lookup for the Grafana ALB — gated by var.grafana_alb_provisioned so
# the FIRST apply (before the Ingress exists) does not fail at plan time.
# -----------------------------------------------------------------------------
data "aws_lb" "grafana" {
  count = var.grafana_alb_provisioned ? 1 : 0

  # The AWS Load Balancer Controller stamps every ALB it manages with this
  # tag. The value is `<namespace>/<ingress-name>` from the Ingress
  # generating it.
  tags = {
    "ingress.k8s.aws/stack" = "monitoring/grafana-ingress"
  }
}

resource "aws_route53_record" "grafana" {
  count = var.grafana_alb_provisioned ? 1 : 0

  zone_id = module.route53.zone_id
  name    = local.grafana_fqdn
  type    = "A"

  alias {
    name                   = data.aws_lb.grafana[0].dns_name
    zone_id                = data.aws_lb.grafana[0].zone_id
    evaluate_target_health = false
  }
}
