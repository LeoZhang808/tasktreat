###############################################################################
# EKS module
#
# Creates an EKS control plane, an EKS-managed node group, and the IAM OIDC
# provider used by IRSA (IAM Roles for Service Accounts). The cluster and
# node IAM roles are passed in from the iam module so role lifecycle stays
# decoupled from cluster lifecycle.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  # The control plane should see both private (where workers + RDS live) and
  # public (for future public LBs) subnets when the public set is provided.
  cluster_subnet_ids = length(var.public_subnet_ids) > 0 ? concat(var.private_subnet_ids, var.public_subnet_ids) : var.private_subnet_ids
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  # Enable EKS access entries so IAM roles (e.g. GitHub Actions OIDC) can be
  # granted Kubernetes API access without editing the aws-auth ConfigMap.
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids              = local.cluster_subnet_ids
    endpoint_public_access  = var.cluster_endpoint_public_access
    endpoint_private_access = var.cluster_endpoint_private_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

# OIDC provider for IRSA. Required so workloads (e.g. AWS LBC, external-dns,
# the app itself) can assume IAM roles via Kubernetes service accounts.
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-oidc"
  })
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = var.node_capacity_type
  disk_size      = var.node_disk_size_gb
  ami_type       = "AL2_x86_64"

  # Bumping `version` (Kubernetes minor) or `release_version` (AMI patch)
  # and re-applying triggers a rolling node replacement, which is exactly the
  # Day 2 OS/security patching mechanism the project needs to demonstrate.
  version         = var.cluster_version
  release_version = var.ami_release_version != "" ? var.ami_release_version : null

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${var.node_group_name}"
  })

  # When you change desired_size out-of-band (e.g. via the AWS console or
  # an autoscaler), don't fight it on the next apply.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
