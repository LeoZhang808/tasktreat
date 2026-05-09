###############################################################################
# Environment outputs.
#
# These are deliberately the values most useful for the next step (kubeconfig
# setup, ECR pushes, RDS connection strings). Sensitive values like the DB
# password are NOT exposed here.
###############################################################################

output "aws_region" {
  description = "Region this environment is deployed to."
  value       = var.aws_region
}

output "name_prefix" {
  description = "Common prefix used for resources in this environment."
  value       = local.name_prefix
}

# ---- VPC --------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

# ---- EKS --------------------------------------------------------------------

output "cluster_name" {
  description = "EKS cluster name (used by `aws eks update-kubeconfig`)."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA cert."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA."
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the cluster."
  value       = module.eks.oidc_provider_arn
}

output "node_group_name" {
  description = "EKS managed node group name."
  value       = module.eks.node_group_name
}

output "cluster_security_group_id" {
  description = "EKS-managed security group attached to nodes/control plane."
  value       = module.eks.cluster_security_group_id
}

# ---- ECR --------------------------------------------------------------------

output "ecr_repository_urls" {
  description = "Map of bare image name -> ECR repository URL."
  value       = module.ecr.repository_urls
}

output "frontend_repository_url" {
  description = "ECR URL for the frontend image."
  value       = module.ecr.frontend_repository_url
}

output "task_service_repository_url" {
  description = "ECR URL for task-service."
  value       = module.ecr.task_service_repository_url
}

output "wishlist_service_repository_url" {
  description = "ECR URL for wishlist-service."
  value       = module.ecr.wishlist_service_repository_url
}

output "reward_service_repository_url" {
  description = "ECR URL for reward-service."
  value       = module.ecr.reward_service_repository_url
}

# ---- RDS --------------------------------------------------------------------

output "rds_endpoint" {
  description = "host:port for the RDS PostgreSQL instance."
  value       = module.rds.rds_endpoint
}

output "rds_address" {
  description = "DNS address of the RDS instance, without the port."
  value       = module.rds.rds_address
}

output "rds_port" {
  description = "PostgreSQL listening port."
  value       = module.rds.rds_port
}

output "rds_database_name" {
  description = "Initial database name."
  value       = module.rds.rds_database_name
}

output "rds_security_group_id" {
  description = "Security group attached to the RDS instance."
  value       = module.rds.rds_security_group_id
}

# ---- Step 5: DNS / TLS / Ingress prerequisites ------------------------------

output "domain_name" {
  description = "Apex domain managed by Route 53 (registered at Name.com)."
  value       = module.route53.zone_name
}

output "app_fqdn" {
  description = "Public hostname the Ingress should serve traffic for."
  value       = local.app_fqdn
}

output "route53_zone_id" {
  description = "Route 53 public hosted zone ID."
  value       = module.route53.zone_id
}

output "route53_name_servers" {
  description = "Authoritative nameservers for the hosted zone. Paste these four into Name.com under \"Manage Nameservers\" so DNS for the domain (and ACM validation) resolves through Route 53."
  value       = module.route53.name_servers
}

output "acm_certificate_arn" {
  description = "ARN of the validated ACM certificate. Used by the Kubernetes Ingress' alb.ingress.kubernetes.io/certificate-arn annotation."
  value       = module.acm.certificate_arn
}

output "acm_certificate_domain_name" {
  description = "Primary FQDN the certificate covers."
  value       = module.acm.certificate_domain_name
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role assumed (via IRSA) by the AWS Load Balancer Controller pod. Pass to Helm via --set serviceAccount.annotations.\"eks\\.amazonaws\\.com/role-arn\"=<this>."
  value       = module.alb_controller_irsa.role_arn
}

# ---- Step 6: CI/CD -----------------------------------------------------------

output "github_actions_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions (repository variable AWS_DEPLOY_ROLE_ARN). Empty when github_repository is not set."
  value       = length(module.github_actions_oidc) > 0 ? module.github_actions_oidc[0].role_arn : ""
}

output "github_actions_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN used in the deploy role trust policy."
  value       = length(module.github_actions_oidc) > 0 ? module.github_actions_oidc[0].oidc_provider_arn : ""
}
