###############################################################################
# Dev environment composition.
#
# Wires the reusable modules together for the `dev` environment. Other
# environments (qa/uat/prod) can reuse the exact same modules with different
# variable values.
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Fully qualified hostname the public app is served from. Built from the
  # `app_subdomain` label (default "app") and the apex `domain_name`. If
  # `app_subdomain` is empty we serve directly from the apex.
  app_fqdn = var.app_subdomain == "" ? var.domain_name : "${var.app_subdomain}.${var.domain_name}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    Course      = var.course
  }
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  eks_cluster_name     = var.eks_cluster_name
  single_nat_gateway   = var.single_nat_gateway

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# IAM (roles consumed by EKS)
# -----------------------------------------------------------------------------

module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# -----------------------------------------------------------------------------
# ECR repositories (one per image)
# -----------------------------------------------------------------------------

module "ecr" {
  source = "../../modules/ecr"

  name_prefix = local.name_prefix

  repository_names = [
    "frontend",
    "task-service",
    "wishlist-service",
    "reward-service",
  ]

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# EKS cluster + managed node group + OIDC provider
# -----------------------------------------------------------------------------

module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_node_role_arn

  node_group_name     = "${local.name_prefix}-workers"
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_desired_size
  node_min_size       = var.eks_min_size
  node_max_size       = var.eks_max_size
  node_disk_size_gb   = var.eks_node_disk_size_gb
  ami_release_version = var.eks_ami_release_version

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# GitHub Actions OIDC — push/pull ECR + kubectl via EKS access entries
# -----------------------------------------------------------------------------

module "github_actions_oidc" {
  count  = var.github_repository != "" ? 1 : 0
  source = "../../modules/github-actions-oidc"

  role_name                  = "${local.name_prefix}-github-actions-deploy-role"
  github_repository          = var.github_repository
  github_oidc_provider_arn   = var.github_oidc_provider_arn
  eks_cluster_name           = var.eks_cluster_name
  ecr_repository_arns        = values(module.ecr.repository_arns)
  tags                       = local.common_tags
}

resource "aws_eks_access_entry" "github_actions" {
  count = var.github_repository != "" ? 1 : 0

  cluster_name      = module.eks.cluster_name
  principal_arn     = module.github_actions_oidc[0].role_arn
  kubernetes_groups = []
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions" {
  count = var.github_repository != "" ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.github_actions_oidc[0].role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  access_scope {
    type       = "namespace"
    namespaces = var.github_actions_k8s_namespaces
  }

  depends_on = [aws_eks_access_entry.github_actions]
}

# -----------------------------------------------------------------------------
# Route 53 — public hosted zone for the Name.com-registered domain.
#
# After the first apply, copy `module.route53.name_servers` into Name.com
# under "Manage Nameservers" so DNS for the apex domain (and ACM DNS
# validation for the cert below) actually resolves through Route 53.
# -----------------------------------------------------------------------------

module "route53" {
  source = "../../modules/route53"

  domain_name = var.domain_name

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# ACM — TLS certificate for the public app hostname (e.g. app.tasktreat.dev).
#
# Validation is DNS-based and the records are created in the Route 53 zone
# above, so this whole step is automatic *as long as* Name.com has been
# pointed at the Route 53 nameservers.
# -----------------------------------------------------------------------------

module "acm" {
  source = "../../modules/acm"

  domain_name    = local.app_fqdn
  hosted_zone_id = module.route53.zone_id

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller — IRSA role.
#
# The controller pod is installed via Helm (see scripts/install-aws-lb-
# controller.sh). Helm will create the kube-system/aws-load-balancer-
# controller service account and annotate it with this role's ARN; AWS
# STS then issues short-lived credentials to that pod whenever it talks
# to the ALB / ELBv2 / EC2 APIs.
# -----------------------------------------------------------------------------

module "alb_controller_irsa" {
  source = "../../modules/aws-load-balancer-controller-irsa"

  cluster_name              = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url   = module.eks.cluster_oidc_issuer_url

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL (private subnets, only EKS workers can connect)
# -----------------------------------------------------------------------------

module "rds" {
  source = "../../modules/rds"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # The cluster security group is automatically attached to every managed
  # node, so allowing inbound from it is equivalent to "EKS workers only".
  # Map keys are static labels so the for_each inside the module can be
  # planned even though the SG ID itself is unknown until EKS is applied.
  allowed_security_groups = {
    "eks-cluster" = module.eks.cluster_security_group_id
  }

  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage_gb    = var.db_allocated_storage_gb
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  skip_final_snapshot     = var.db_skip_final_snapshot
  deletion_protection     = var.db_deletion_protection

  tags = local.common_tags
}
