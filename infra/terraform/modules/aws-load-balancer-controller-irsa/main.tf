###############################################################################
# AWS Load Balancer Controller — IRSA module
#
# Creates the IAM plumbing the AWS Load Balancer Controller needs to
# create and manage AWS ALBs / NLBs from inside the cluster:
#
#   * Customer-managed IAM policy that exactly matches the official
#     `iam_policy.json` shipped by the upstream project.
#   * IAM role that the in-cluster service account assumes via the EKS
#     OIDC provider (IRSA).
#   * Trust policy scoped to the specific Kubernetes service account
#     (`kube-system/aws-load-balancer-controller`) so no other workload
#     in the cluster can assume the role.
#
# This module does NOT install the controller itself; that step is done
# by `helm upgrade --install aws-load-balancer-controller ...` (see
# `scripts/install-aws-lb-controller.sh`). The Helm chart's service
# account is annotated with the role ARN this module outputs.
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

# Strip the "https://" prefix from the OIDC issuer URL because both the
# StringEquals condition keys and the federated principal ARN use the
# bare hostname/path form ("oidc.eks.<region>.amazonaws.com/id/XXXX").
locals {
  oidc_provider_url = replace(var.cluster_oidc_issuer_url, "https://", "")
  service_account   = "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"
  role_name         = "${var.cluster_name}-alb-controller"
  policy_name       = "${var.cluster_name}-alb-controller"
}

# ---- IAM policy -------------------------------------------------------------
#
# The official policy is checked into the module so apply is hermetic and
# does not depend on a network round-trip to GitHub at plan time.

resource "aws_iam_policy" "this" {
  name        = local.policy_name
  description = "Permissions required by the AWS Load Balancer Controller in EKS cluster ${var.cluster_name}."
  policy      = file("${path.module}/iam_policy.json")

  tags = merge(var.tags, {
    Name      = local.policy_name
    Component = "aws-load-balancer-controller"
  })
}

# ---- IAM role (assumed via EKS OIDC) ---------------------------------------

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.cluster_oidc_provider_arn]
    }

    # Lock the trust to the specific Kubernetes service account so only the
    # AWS LBC pod (and not e.g. an attacker who hijacks an unrelated SA in
    # the cluster) can assume this role.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = [local.service_account]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.role_name
  description        = "Assumed by the AWS Load Balancer Controller service account in cluster ${var.cluster_name} via IRSA."
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = merge(var.tags, {
    Name      = local.role_name
    Component = "aws-load-balancer-controller"
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
